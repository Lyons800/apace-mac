import ApaceClients
import ApaceCore

extension TranscriberClient {
    /// Resolves an engine choice to a concrete client. All three engines are wired up:
    /// Apple's built-in recogniser, Whisper (WhisperKit), and Parakeet (FluidAudio).
    /// Whisper and Parakeet download their model on first use.
    public static func make(for engine: TranscriptionEngine) -> TranscriberClient {
        switch engine {
        case .apple: apple
        case .whisper: whisperKit
        case .parakeet: parakeet
        }
    }

    /// Warms up an engine's model in the background so the first dictation is instant.
    public static func preload(_ engine: TranscriptionEngine) {
        switch engine {
        case .apple: break
        case .whisper: Task { await WhisperKitEngine.shared.preload() }
        case .parakeet: Task { await ParakeetEngine.shared.preload() }
        }
    }

    static let parakeet = TranscriberClient(
        stream: { _ in AsyncThrowingStream { $0.finish() } },
        transcribe: { try await ParakeetEngine.shared.transcribe($0) }
    )

    static let whisperKit = TranscriberClient(
        stream: { _ in AsyncThrowingStream { $0.finish() } },
        transcribe: { try await WhisperKitEngine.shared.transcribe($0) }
    )
}
