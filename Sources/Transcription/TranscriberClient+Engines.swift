import ApaceClients
import ApaceCore

extension TranscriberClient {
    /// Resolves an engine choice to a concrete client.
    ///
    /// Apple is wired up today; Whisper and Parakeet are declared but not yet
    /// integrated, so they resolve to a client that fails clearly. That way selecting
    /// an engine that isn't ready surfaces a real, recoverable error instead of
    /// silently transcribing nothing.
    public static func make(for engine: TranscriptionEngine) -> TranscriberClient {
        switch engine {
        case .apple: apple
        case .whisper, .parakeet: unavailable(engine)
        }
    }

    /// A client that reports a specific engine as unavailable on both channels.
    static func unavailable(_ engine: TranscriptionEngine) -> TranscriberClient {
        TranscriberClient(
            stream: { _ in
                AsyncThrowingStream {
                    $0.finish(throwing: TranscriptionError.engineUnavailable(engine))
                }
            },
            transcribe: { _ in throw TranscriptionError.engineUnavailable(engine) }
        )
    }
}
