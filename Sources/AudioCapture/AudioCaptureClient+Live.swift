import ApaceClients
import ApaceCore

public extension AudioCaptureClient {
    /// Live microphone capture backed by `AVAudioEngine` — taps the input node,
    /// converts to 16 kHz mono float, and feeds a lock-free ring buffer.
    ///
    /// - Note: Implemented in milestone M1 (the core dictation loop). The current
    ///   value is an inert placeholder so the module compiles and the composition
    ///   root can already reference `.live`.
    static let live = AudioCaptureClient(
        start: { AsyncStream { $0.finish() } },
        stop: { [] }
    )
}
