import ApaceClients
import ApaceCore
import Observation

/// The observable store behind onboarding and the settings permissions section. It
/// holds each permission's current status and exposes refresh, request, and
/// open-settings actions. Runs on the main actor (the module default).
@Observable
public final class PermissionsModel {
    public private(set) var statuses: [Permission: PermissionStatus] = [:]
    public private(set) var requestedPermissions: Set<Permission> = []

    private let client: PermissionsClient
    private let persistRequest: @Sendable (Permission) -> Void
    private let requiredPermissionsProvider: @Sendable () -> [Permission]

    public init(
        client: PermissionsClient,
        requestedPermissions: Set<Permission> = PermissionRequestPreference.requested,
        persistRequest: @escaping @Sendable (Permission) -> Void = {
            PermissionRequestPreference.mark($0)
        },
        requiredPermissions: @escaping @Sendable () -> [Permission] = {
            var required: [Permission] = [.microphone, .inputMonitoring, .accessibility]
            if EnginePreference.engine == .apple { required.insert(.speechRecognition, at: 1) }
            if CommandPreference.usesVision || CommandPreference.controlEnabled {
                required.append(.screenRecording)
            }
            return required
        }
    ) {
        self.client = client
        self.requestedPermissions = requestedPermissions
        self.persistRequest = persistRequest
        requiredPermissionsProvider = requiredPermissions
        refresh()
    }

    /// Whether every permission Apace needs has been granted.
    public var allGranted: Bool {
        requiredPermissions.allSatisfy { statuses[$0] == .granted }
    }

    public var requiredPermissions: [Permission] { requiredPermissionsProvider() }

    public func isRequired(_ permission: Permission) -> Bool {
        requiredPermissions.contains(permission)
    }

    public func status(_ permission: Permission) -> PermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    public func hasRequested(_ permission: Permission) -> Bool {
        requestedPermissions.contains(permission)
    }

    /// Re-reads every status. Cheap; call it when a window appears or regains focus,
    /// since the user may have changed a grant in System Settings.
    public func refresh() {
        for permission in Permission.allCases {
            statuses[permission] = effectiveStatus(
                client.status(permission),
                permission: permission
            )
        }
    }

    /// Prompts for a permission and records the outcome.
    public func request(_ permission: Permission) async {
        requestedPermissions.insert(permission)
        persistRequest(permission)
        statuses[permission] = effectiveStatus(
            await client.request(permission),
            permission: permission
        )
    }

    public func openSettings(_ permission: Permission) {
        client.openSettings(permission)
    }

    private func effectiveStatus(
        _ status: PermissionStatus,
        permission: Permission
    ) -> PermissionStatus {
        guard status == .notDetermined, requestedPermissions.contains(permission) else {
            return status
        }
        // AVFoundation and Speech expose a real not-determined state. The two event
        // access APIs do not, so after the first request a false preflight means the
        // user must repair the grant in System Settings.
        switch permission {
        case .inputMonitoring, .accessibility, .screenRecording: return PermissionStatus.denied
        case .microphone, .speechRecognition: return PermissionStatus.notDetermined
        }
    }
}
