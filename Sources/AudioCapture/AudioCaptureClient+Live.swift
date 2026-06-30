@preconcurrency import AVFoundation
import ApaceClients
import ApaceCore
import Foundation

extension AudioCaptureClient {
    /// Live microphone capture backed by `AVAudioEngine`. It taps the input node,
    /// converts whatever the hardware delivers down to 16 kHz mono float (the format
    /// every engine expects), hands each converted chunk to the preview stream, and
    /// keeps a complete loss-less copy for the accurate final pass.
    ///
    /// One recorder instance backs both closures so `start` and `stop` act on the same
    /// engine and buffer.
    public static let live: AudioCaptureClient = {
        let recorder = MicrophoneRecorder()
        return AudioCaptureClient(
            start: { try recorder.start() },
            stop: { recorder.stop() }
        )
    }()
}

/// Errors the live adapter can raise on `start`; surfaced to the user as a recoverable
/// failure by the coordinator.
enum AudioCaptureError: Error {
    case formatUnavailable
}

/// Owns the audio engine and the recording buffer. Marked `@unchecked Sendable`
/// because its mutable state is reached from two places — the caller's thread
/// (`start`/`stop`) and the real-time render thread (the tap) — and every access goes
/// through `lock`. The tap does only the unavoidable work (convert, append, hand off);
/// it never touches the actor system.
final class MicrophoneRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()

    private var recorded: [Float] = []
    private var continuation: AsyncStream<AudioChunk>.Continuation?
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    func start() throws -> AsyncStream<AudioChunk> {
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )
        else {
            throw AudioCaptureError.formatUnavailable
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.formatUnavailable
        }

        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream(
            bufferingPolicy: .bufferingNewest(16)
        )

        lock.withLock {
            recorded.removeAll(keepingCapacity: true)
            self.continuation = continuation
            self.converter = converter
            self.targetFormat = targetFormat
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.capture(buffer)
        }
        engine.prepare()
        try engine.start()
        return stream
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        return lock.withLock {
            continuation?.finish()
            continuation = nil
            converter = nil
            targetFormat = nil
            return recorded
        }
    }

    /// Runs on the real-time audio thread. Converts the buffer, appends it to the
    /// loss-less record under the lock, then yields a chunk to the preview stream
    /// (outside the lock); back-pressure on the preview is handled by the stream's
    /// buffering policy, which drops the oldest chunks rather than stalling capture.
    private func capture(_ buffer: AVAudioPCMBuffer) {
        let (converter, targetFormat, continuation) = lock.withLock {
            (self.converter, self.targetFormat, self.continuation)
        }
        guard let converter, let targetFormat else { return }
        guard let chunk = Self.convert(buffer, with: converter, to: targetFormat), !chunk.isEmpty
        else { return }

        lock.withLock { recorded.append(contentsOf: chunk) }
        continuation?.yield(AudioChunk(samples: chunk))
    }

    /// Resamples one input buffer to the target format and copies out the mono float
    /// samples. Returns `nil` if the conversion fails, so a bad buffer is skipped
    /// rather than corrupting the stream.
    private static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to targetFormat: AVAudioFormat
    ) -> [Float]? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return nil
        }

        // The converter calls this block synchronously on the current thread for this
        // one buffer, so the single-shot flag is safe despite the `@Sendable` block.
        nonisolated(unsafe) var supplied = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }

        guard conversionError == nil, let channel = output.floatChannelData?.pointee else {
            return nil
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}
