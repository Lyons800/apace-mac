import ApaceClients
import ApaceCore

extension TranscriberClient {
    /// Resolves an engine choice to a concrete client. All three engines are wired up:
    /// Apple's built-in recogniser, Whisper (WhisperKit), and Parakeet (FluidAudio).
    /// Whisper and Parakeet download their model on first use.
    public static func make(for engine: TranscriptionEngine) -> TranscriberClient {
        switch engine {
        case .apple: apple
        case .parakeet: parakeet(.v3)
        case .parakeetEnglish: parakeet(.v2)
        case .whisper: whisper(.turbo)
        case .whisperMax: whisper(.largeV3)
        }
    }

    /// Warms up an engine's model in the background so the first dictation is instant.
    public static func preload(_ engine: TranscriptionEngine) {
        switch engine {
        case .apple: break
        case .parakeet: Task { await ParakeetEngine.v3.preload() }
        case .parakeetEnglish: Task { await ParakeetEngine.v2.preload() }
        case .whisper: Task { await WhisperKitEngine.turbo.preload() }
        case .whisperMax: Task { await WhisperKitEngine.largeV3.preload() }
        }
    }

    /// Awaits the engine's model being ready (downloaded + loaded), for the first-run
    /// "preparing model" indicator. Apple's engine needs no download and returns at once.
    public static func prepare(_ engine: TranscriptionEngine) async {
        switch engine {
        case .apple: break
        case .parakeet: await ParakeetEngine.v3.prepare()
        case .parakeetEnglish: await ParakeetEngine.v2.prepare()
        case .whisper: await WhisperKitEngine.turbo.prepare()
        case .whisperMax: await WhisperKitEngine.largeV3.prepare()
        }
    }

    static func parakeet(_ engine: ParakeetEngine) -> TranscriberClient {
        TranscriberClient(
            stream: { _ in AsyncThrowingStream { $0.finish() } },
            transcribe: { try await engine.transcribe($0) }
        )
    }

    static func whisper(_ engine: WhisperKitEngine) -> TranscriberClient {
        TranscriberClient(
            stream: { _ in AsyncThrowingStream { $0.finish() } },
            transcribe: { try await engine.transcribe($0) }
        )
    }
}
