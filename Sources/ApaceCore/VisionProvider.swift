/// Which model answers a spoken command, optionally looking at a screenshot. On-device
/// uses Apple's Foundation Models (which gained image understanding on macOS 26); the
/// cloud providers each use the user's own key. Mirrors ``CleanupProvider`` so both
/// slot into the on-device-vs-cloud mode.
public enum VisionProvider: String, CaseIterable, Sendable, Codable {
    case onDevice
    case gemini

    public static let `default` = VisionProvider.onDevice

    public var displayName: String {
        switch self {
        case .onDevice: "On-device (Apple Intelligence)"
        case .gemini: "Google Gemini"
        }
    }

    public var requiresAPIKey: Bool { self != .onDevice }

    /// Keychain account for this provider's key.
    public var keyAccount: String { "vision.\(rawValue).apiKey" }

    /// The provider this mode recommends for command answers.
    public static func recommended(for mode: ProcessingMode) -> VisionProvider {
        switch mode {
        case .onDevice: .onDevice
        case .cloud: .gemini
        }
    }
}
