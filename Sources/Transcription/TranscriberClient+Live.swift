import ApaceClients
import ApaceCore

public extension TranscriberClient {
    /// Live transcription. The three engines we ship — WhisperKit (CoreML),
    /// Parakeet (FluidAudio), and Apple `SpeechAnalyzer` — are normalised behind a
    /// single `ASREngine` boundary so their differing streaming idioms collapse to
    /// one `AsyncStream<ASRUpdate>`.
    ///
    /// - Note: Engines and model management land in milestone M2. Placeholder for now.
    static let live = TranscriberClient(
        stream: { _ in AsyncThrowingStream { $0.finish() } },
        transcribe: { _ in "" }
    )
}
