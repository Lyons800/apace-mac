import ApaceCore

/// The port for checking and requesting the system permissions Apace needs. The live
/// adapter wraps AVFoundation, Speech, Core Graphics event access, and Accessibility;
/// onboarding drives it, and tests swap in canned statuses.
public struct PermissionsClient: Sendable {
    /// The current grant state, cheap to call for polling the UI.
    public var status: @Sendable (Permission) -> PermissionStatus
    /// Prompts for a permission and returns the resulting state. Some macOS privacy
    /// grants require confirmation in System Settings, so the UI keeps polling.
    public var request: @Sendable (Permission) async -> PermissionStatus
    /// Opens the relevant System Settings pane, for a permission the user has to
    /// change there.
    public var openSettings: @Sendable (Permission) -> Void

    public init(
        status: @escaping @Sendable (Permission) -> PermissionStatus,
        request: @escaping @Sendable (Permission) async -> PermissionStatus,
        openSettings: @escaping @Sendable (Permission) -> Void
    ) {
        self.status = status
        self.request = request
        self.openSettings = openSettings
    }
}
