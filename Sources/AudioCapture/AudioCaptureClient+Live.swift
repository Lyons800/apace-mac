@preconcurrency import AVFoundation
import ApaceClients
import ApaceCore
import AudioToolbox
import Foundation

extension AudioCaptureClient {
    /// Live microphone capture backed by `AVAudioEngine`. It taps the input node,
    /// converts whatever the hardware delivers down to 16 kHz mono float (the format
    /// every engine expects), hands each converted chunk to the preview stream, and
    /// keeps a complete loss-less copy for the accurate final pass.
    ///
    /// One recorder instance backs both closures so `start` and `stop` act on the same
    /// engine and buffer.
    public static let live = microphone()

    /// Creates an independent recorder. Pronunciation learning uses its own instance so
    /// opening Settings can never steal or stop the recorder used by normal dictation.
    public static func microphone() -> AudioCaptureClient {
        let recorder = MicrophoneRecorder()
        return AudioCaptureClient(
            start: { try recorder.start() },
            samples: { recorder.currentSamples() },
            stop: { recorder.stop() }
        )
    }
}

/// Errors the live adapter can raise on `start`; surfaced to the user as a recoverable
/// failure by the coordinator.
enum AudioCaptureError: Error {
    case formatUnavailable
    case microphoneUnavailable
}

/// Owns the audio engine and the recording buffer. Marked `@unchecked Sendable`
/// because its mutable state is reached from two places — the caller's thread
/// (`start`/`stop`) and the real-time render thread (the tap) — and every access goes
/// through `lock`. The tap does only the unavoidable work (convert, append, hand off);
/// it never touches the actor system.
final class MicrophoneRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let recoveryQueue = DispatchQueue(label: "so.apace.audio-recovery")

    private var engine: AVAudioEngine?
    private var recorded: [Float] = []
    private var continuation: AsyncStream<AudioChunk>.Continuation?
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var configurationObserver: NSObjectProtocol?
    private var isRecovering = false
    private var recordingGeneration = 0

    func start() throws -> AsyncStream<AudioChunk> {
        // A fresh engine binds to the current system input device. Reusing a long-lived
        // engine can leave it attached to a vanished built-in microphone after clamshell,
        // dock, headset, or display changes.
        let engine = AVAudioEngine()
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
        let microphoneName = Self.applyPreferredDevice(to: input)

        // Never install over an existing tap — `installTap` throws an *Objective-C*
        // exception (uncatchable in Swift, so a hard crash) if a tap is already there.
        input.removeTap(onBus: 0)

        // A missing/denied mic surfaces as a zero-channel, zero-rate format; installing a
        // tap with it also throws that uncatchable exception. Bail out with a Swift error
        // the coordinator can turn into a friendly "couldn't access the microphone".
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw AudioCaptureError.microphoneUnavailable
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.formatUnavailable
        }

        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream(
            bufferingPolicy: .bufferingNewest(16)
        )

        lock.withLock {
            recordingGeneration &+= 1
            recorded.removeAll(keepingCapacity: true)
            self.engine = engine
            self.continuation = continuation
            self.converter = converter
            self.targetFormat = targetFormat
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.capture(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            lock.withLock {
                self.engine = nil
                self.continuation = nil
                self.converter = nil
                self.targetFormat = nil
            }
            throw error
        }
        if let microphoneName {
            DictationHealthRecorder.shared.record(.microphone(microphoneName))
        }
        observeConfigurationChanges(for: engine)
        return stream
    }

    /// A copy of everything captured so far, for the live-preview re-transcription.
    func currentSamples() -> [Float] {
        lock.withLock { recorded }
    }

    func stop() -> [Float] {
        let (activeEngine, observer) = lock.withLock { (engine, configurationObserver) }
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let activeEngine {
            activeEngine.inputNode.removeTap(onBus: 0)
            if activeEngine.isRunning {
                activeEngine.stop()
            }
        }
        return lock.withLock {
            recordingGeneration &+= 1
            engine = nil
            configurationObserver = nil
            isRecovering = false
            continuation?.finish()
            continuation = nil
            converter = nil
            targetFormat = nil
            return recorded
        }
    }

    /// Headsets and display/dock microphones can disappear mid-recording. AVAudioEngine
    /// then posts a configuration change and commonly stops. Rebuild it on a serial
    /// queue, keeping the already-recorded samples and the same preview stream.
    private func observeConfigurationChanges(for engine: AVAudioEngine) {
        let observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self, weak engine] _ in
            guard let self, let engine else { return }
            self.recoveryQueue.async { self.recover(changedEngine: engine) }
        }
        let accepted = lock.withLock { () -> Bool in
            guard self.engine === engine else { return false }
            configurationObserver = observer
            return true
        }
        if !accepted { NotificationCenter.default.removeObserver(observer) }
    }

    private func recover(changedEngine: AVAudioEngine) {
        let generation = lock.withLock { () -> Int? in
            guard engine === changedEngine, !isRecovering else { return nil }
            isRecovering = true
            return recordingGeneration
        }
        guard let generation else { return }

        if let observer = lock.withLock({ configurationObserver }) {
            NotificationCenter.default.removeObserver(observer)
        }
        changedEngine.inputNode.removeTap(onBus: 0)
        if changedEngine.isRunning { changedEngine.stop() }

        do {
            let replacement = AVAudioEngine()
            let input = replacement.inputNode
            let microphoneName = Self.applyPreferredDevice(to: input)
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0,
                let targetFormat = lock.withLock({ self.targetFormat }),
                let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            else { throw AudioCaptureError.microphoneUnavailable }

            input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
                [weak self] buffer, _ in self?.capture(buffer)
            }
            replacement.prepare()
            try replacement.start()
            let stillRecording = lock.withLock { () -> Bool in
                guard recordingGeneration == generation, engine === changedEngine else {
                    return false
                }
                engine = replacement
                self.converter = converter
                configurationObserver = nil
                isRecovering = false
                return true
            }
            guard stillRecording else {
                input.removeTap(onBus: 0)
                replacement.stop()
                return
            }
            observeConfigurationChanges(for: replacement)
            if let microphoneName {
                DictationHealthRecorder.shared.record(.microphone(microphoneName))
            }
        } catch {
            // Keep the captured audio recoverable. Stop will still return it, and a new
            // dictation creates a fresh engine against the then-current default device.
            lock.withLock {
                guard recordingGeneration == generation, engine === changedEngine else { return }
                engine = nil
                configurationObserver = nil
                isRecovering = false
            }
        }
    }

    private static func applyPreferredDevice(to input: AVAudioInputNode) -> String? {
        guard let uid = MicrophonePreference.selectedUID,
            let device = CoreAudioInputs.device(uid: uid),
            let audioUnit = input.audioUnit
        else { return CoreAudioInputs.defaultDevice()?.value.name }
        var objectID = device.objectID
        let result = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &objectID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        // If the saved device vanished or cannot be opened, leaving the property alone
        // makes AVAudioEngine use the current macOS default.
        return result == noErr ? device.value.name : CoreAudioInputs.defaultDevice()?.value.name
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
