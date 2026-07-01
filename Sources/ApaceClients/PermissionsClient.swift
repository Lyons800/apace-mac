import ApaceCore

/// The port for checking and requesting the system permissions Apace needs. The live
/// adapter wraps AVFoundation, Speech, and the Accessibility API; onboarding drives
/// it, and tests swap in canned statuses.
public struct PermissionsClient: Sendable {
    /// The current grant state, cheap to call for polling the UI.
    public var status: @Sendable (Permission) -> PermissionStatus
    /// Prompts for a permission and returns the resulting state. Accessibility can't
    /// be granted in-app, so its request opens the prompt and reports back.
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
