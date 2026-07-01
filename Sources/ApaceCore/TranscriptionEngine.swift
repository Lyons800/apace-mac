/// The on-device speech engines Apace can transcribe with.
///
/// The choice is a plain value with no engine framework behind it, so settings can
/// persist it and the UI can list it without the domain or the UI depending on
/// WhisperKit, FluidAudio, or Speech. The `Transcription` module maps each case to a
/// concrete `TranscriberClient`.
public enum TranscriptionEngine: String, CaseIterable, Sendable, Codable {
    /// Apple's built-in recogniser. Always available and needs no download.
    case apple
    /// OpenAI Whisper via Core ML (WhisperKit). Higher accuracy; downloads a model.
    case whisper
    /// NVIDIA Parakeet via FluidAudio. Fast; downloads a model.
    case parakeet

    /// The engine used until the user picks another. Parakeet is the default because
    /// it's the strongest on-device option — fast and accurate, and it transcribes the
    /// whole utterance without splitting on pauses.
    public static let `default` = TranscriptionEngine.parakeet

    /// Name shown to the user.
    public var displayName: String {
        switch self {
        case .apple: "Apple"
        case .whisper: "Whisper"
        case .parakeet: "Parakeet"
        }
    }

    /// Whether the engine has to fetch a model the first time it is used. Apple's is
    /// already on the system; the others are downloaded on demand.
    public var requiresModelDownload: Bool {
        switch self {
        case .apple: false
        case .whisper, .parakeet: true
        }
    }
}
