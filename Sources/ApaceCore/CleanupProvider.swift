/// Which model cleans up a finished transcript. On-device is the default and needs no
/// key; the cloud providers each use the user's own API key, stored in the Keychain.
public enum CleanupProvider: String, CaseIterable, Sendable, Codable {
    /// Apple Intelligence on macOS 26 (a local Qwen model for older Macs is planned).
    case onDevice
    case anthropic
    case groq
    case openai
    case gemini

    public static let `default` = CleanupProvider.onDevice

    public var displayName: String {
        switch self {
        case .onDevice: "On-device (Apple Intelligence)"
        case .anthropic: "Anthropic (Claude)"
        case .groq: "Groq"
        case .openai: "OpenAI"
        case .gemini: "Google Gemini"
        }
    }

    /// Cloud providers need a key; on-device doesn't.
    public var requiresAPIKey: Bool { self != .onDevice }

    /// Keychain account for this provider's key.
    public var keyAccount: String { "cleanup.\(rawValue).apiKey" }
}
