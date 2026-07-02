/// The user's overall stance on where processing runs. It's a convenience that sets the
/// recommended model for each capability in one move; individual capabilities can still
/// be overridden afterwards. Transcription stays on-device in both modes — the best
/// on-device model (Parakeet) is faster than and as accurate as the cloud options, so
/// there's nothing to gain by sending audio away.
public enum ProcessingMode: String, CaseIterable, Sendable, Codable {
    /// Everything runs on the Mac — private and offline.
    case onDevice
    /// Cloud models where they genuinely help (cleanup, vision), with the user's key.
    case cloud

    public static let `default` = ProcessingMode.onDevice

    public var displayName: String {
        switch self {
        case .onDevice: "On-device"
        case .cloud: "Cloud"
        }
    }

    /// The cleanup provider this mode recommends. On-device uses Apple Intelligence (or
    /// a local model); cloud defaults to Anthropic, which the user can change.
    public var recommendedCleanupProvider: CleanupProvider {
        switch self {
        case .onDevice: .onDevice
        case .cloud: .anthropic
        }
    }
}
