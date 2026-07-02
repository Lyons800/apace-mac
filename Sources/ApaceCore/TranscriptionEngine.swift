/// The on-device speech engines Apace can transcribe with.
///
/// The choice is a plain value with no engine framework behind it, so settings can
/// persist it and the UI can list it without the domain or the UI depending on
/// WhisperKit, FluidAudio, or Speech. The `Transcription` module maps each case to a
/// concrete `TranscriberClient`.
public enum TranscriptionEngine: String, CaseIterable, Sendable, Codable {
    /// Apple's built-in recogniser. Always available and needs no download.
    case apple
    /// Parakeet TDT v3 (FluidAudio) — multilingual, fast, the balanced default.
    case parakeet
    /// Parakeet TDT v2 (FluidAudio) — English-only, highest English accuracy.
    case parakeetEnglish
    /// Whisper large-v3 turbo (WhisperKit) — broad language support at good speed.
    case whisper
    /// Whisper large-v3 (WhisperKit) — maximum accuracy, slower and larger.
    case whisperMax

    /// The engine used until the user picks another. Parakeet is the default because
    /// it's the strongest all-round on-device option — fast and accurate, and it
    /// transcribes the whole utterance without splitting on pauses.
    public static let `default` = TranscriptionEngine.parakeet

    /// Name shown to the user.
    public var displayName: String {
        switch self {
        case .apple: "Apple"
        case .parakeet: "Parakeet (Balanced)"
        case .parakeetEnglish: "Parakeet (English, max accuracy)"
        case .whisper: "Whisper (Turbo)"
        case .whisperMax: "Whisper (Max accuracy)"
        }
    }

    /// Whether the engine has to fetch a model the first time it is used. Apple's is
    /// already on the system; the others are downloaded on demand.
    public var requiresModelDownload: Bool {
        switch self {
        case .apple: false
        default: true
        }
    }
}
