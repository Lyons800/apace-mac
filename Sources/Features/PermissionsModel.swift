import ApaceClients
import ApaceCore
import Observation

/// The observable store behind onboarding and the settings permissions section. It
/// holds each permission's current status and exposes refresh, request, and
/// open-settings actions. Runs on the main actor (the module default).
@Observable
public final class PermissionsModel {
    public private(set) var statuses: [Permission: PermissionStatus] = [:]

    private let client: PermissionsClient

    public init(client: PermissionsClient) {
        self.client = client
        refresh()
    }

    /// Whether every permission Apace needs has been granted.
    public var allGranted: Bool {
        Permission.allCases.allSatisfy { statuses[$0] == .granted }
    }

    public func status(_ permission: Permission) -> PermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    /// Re-reads every status. Cheap; call it when a window appears or regains focus,
    /// since the user may have changed a grant in System Settings.
    public func refresh() {
        for permission in Permission.allCases {
            statuses[permission] = client.status(permission)
        }
    }

    /// Prompts for a permission and records the outcome.
    public func request(_ permission: Permission) async {
        statuses[permission] = await client.request(permission)
    }

    public func openSettings(_ permission: Permission) {
        client.openSettings(permission)
    }
}
