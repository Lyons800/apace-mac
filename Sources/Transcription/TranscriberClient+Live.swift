@preconcurrency import AVFoundation
import ApaceClients
import ApaceCore
@preconcurrency import Speech

extension TranscriberClient {
    /// Apple's on-device speech recogniser — the baseline engine. Recognition is
    /// pinned on-device so audio never leaves the machine, which is the whole point.
    public static let apple = TranscriberClient(
        stream: { AppleSpeech.stream($0) },
        transcribe: { try await AppleSpeech.transcribe($0) }
    )

    /// The engine the app uses today. Milestone M2 turns this into a choice between
    /// Apple, WhisperKit, and Parakeet behind the same port.
    public static let live = apple
}

/// Errors surfaced from the speech adapter; the coordinator turns them into a
/// recoverable failure the user can retry.
enum TranscriptionError: Error {
    case notAuthorized
    case recognizerUnavailable
    case audioBufferUnavailable
}

/// The mechanics of driving `SFSpeechRecognizer`, kept off the `TranscriberClient`
/// value so the port stays a plain struct of closures.
private enum AppleSpeech {
    /// One accurate, on-device pass over a finished recording. This result is what
    /// actually gets inserted.
    static func transcribe(_ samples: [Float]) async throws -> String {
        guard !samples.isEmpty else { return "" }
        try await requestAuthorization()

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        guard let buffer = makeBuffer(from: samples) else {
            throw TranscriptionError.audioBufferUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.append(buffer)
        request.endAudio()

        // `recognizer` stays in scope across the suspension, which keeps the in-flight
        // task alive until the final result arrives.
        return try await withCheckedThrowingContinuation { continuation in
            nonisolated(unsafe) var settled = false
            _ = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !settled {
                        settled = true
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let result, result.isFinal, !settled else { return }
                settled = true
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }

    /// Volatile, on-device partials for the live preview. Best-effort: any failure
    /// just ends the preview and leaves the final pass to stand.
    static func stream(_ audio: AsyncStream<AudioChunk>) -> AsyncThrowingStream<ASRUpdate, Error> {
        AsyncThrowingStream { continuation in
            let work = Task {
                do {
                    try await requestAuthorization()
                    guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
                        throw TranscriptionError.recognizerUnavailable
                    }

                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.requiresOnDeviceRecognition = true
                    request.shouldReportPartialResults = true

                    try await withCheckedThrowingContinuation {
                        (finished: CheckedContinuation<Void, Error>) in
                        nonisolated(unsafe) var settled = false
                        _ = recognizer.recognitionTask(with: request) { result, error in
                            if let error {
                                if !settled {
                                    settled = true
                                    finished.resume(throwing: error)
                                }
                                return
                            }
                            guard let result else { return }
                            continuation.yield(
                                ASRUpdate(
                                    text: result.bestTranscription.formattedString,
                                    isFinal: result.isFinal
                                )
                            )
                            if result.isFinal, !settled {
                                settled = true
                                finished.resume()
                            }
                        }

                        // Feed audio on its own task so this closure can return and the
                        // recognition callback above can start firing.
                        Task {
                            for await chunk in audio {
                                if let buffer = makeBuffer(from: chunk.samples) {
                                    request.append(buffer)
                                }
                            }
                            request.endAudio()
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    private static func requestAuthorization() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard status == .authorized else { throw TranscriptionError.notAuthorized }
        default:
            throw TranscriptionError.notAuthorized
        }
    }

    /// Wraps 16 kHz mono float samples in the `AVAudioPCMBuffer` the recogniser wants.
    private static func makeBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard
            !samples.isEmpty,
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            ),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(samples.count)
            ),
            let channel = buffer.floatChannelData?.pointee
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
                channel.update(from: base, count: samples.count)
            }
        }
        return buffer
    }
}
