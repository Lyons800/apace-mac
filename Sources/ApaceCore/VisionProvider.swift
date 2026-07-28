/// Which model answers a spoken command, optionally looking at a screenshot. On-device
/// uses Apple's Foundation Models (which gained image understanding on macOS 26); the
/// cloud providers each use the user's own key. Mirrors ``CleanupProvider`` so both
/// slot into the on-device-vs-cloud mode.
public enum VisionProvider: String, CaseIterable, Sendable, Codable {
    case onDevice
    case anthropic
    case gemini

    public static let `default` = VisionProvider.onDevice

    public var displayName: String {
        switch self {
        case .onDevice: "On-device (Apple Intelligence)"
        case .anthropic: "Anthropic (Claude)"
        case .gemini: "Google Gemini"
        }
    }

    public var requiresAPIKey: Bool { self != .onDevice }

    /// Whether this provider can accept a screenshot alongside the question. On-device
    /// Foundation Models are text-only until Apple's image API ships, so capturing a
    /// screenshot for them is wasted work.
    public var supportsImages: Bool { self != .onDevice }

    /// Keychain account for this provider's key. Anthropic shares the Cleanup key —
    /// one key drives cleanup, computer-use, and vision, entered once.
    public var keyAccount: String {
        switch self {
        case .anthropic: CleanupProvider.anthropic.keyAccount
        default: "vision.\(rawValue).apiKey"
        }
    }

    /// The provider this mode recommends for command answers.
    public static func recommended(for mode: ProcessingMode) -> VisionProvider {
        switch mode {
        case .onDevice: .onDevice
        case .cloud: .anthropic
        }
    }
}
