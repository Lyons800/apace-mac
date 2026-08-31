import ApaceClients
import ApaceCore
import Testing

@testable import Features

@MainActor
@Suite("Permissions model")
struct PermissionsModelTests {
    @Test("Reads each permission's status on load")
    func readsStatuses() {
        let model = testModel(client: .stub(.notDetermined))
        #expect(model.status(.microphone) == .notDetermined)
        #expect(model.allGranted == false)
    }

    @Test("All-granted is true only when every permission is granted")
    func allGranted() {
        #expect(testModel(client: .stub(.granted)).allGranted)
    }

    @Test("An optional permission does not block onboarding")
    func optionalPermissionDoesNotBlock() {
        let client = PermissionsClient(
            status: { $0 == .speechRecognition ? .denied : .granted },
            request: { _ in .granted },
            openSettings: { _ in }
        )
        let model = testModel(
            client: client,
            required: [.microphone, .inputMonitoring, .accessibility]
        )
        #expect(model.allGranted)
    }

    @Test("Requesting a permission records the returned status")
    func requestRecordsResult() async {
        let model = testModel(client: .stub(.notDetermined, onRequest: .granted))
        await model.request(.microphone)
        #expect(model.status(.microphone) == .granted)
        #expect(model.hasRequested(.microphone))
    }

    @Test("Previously requested event permissions are shown as denied, not endlessly grantable")
    func requestedEventPermissionNeedsSettings() {
        let model = testModel(
            client: .stub(.notDetermined),
            requested: [.inputMonitoring, .accessibility]
        )
        #expect(model.status(.inputMonitoring) == .denied)
        #expect(model.status(.accessibility) == .denied)
        #expect(model.status(.microphone) == .notDetermined)
    }

    private func testModel(
        client: PermissionsClient,
        requested: Set<Permission> = [],
        required: [Permission] = Permission.allCases
    ) -> PermissionsModel {
        PermissionsModel(
            client: client,
            requestedPermissions: requested,
            persistRequest: { _ in },
            requiredPermissions: { required }
        )
    }
}

extension PermissionsClient {
    /// A stub that reports one status for everything, and optionally a different one
    /// after a request.
    static func stub(
        _ status: PermissionStatus,
        onRequest: PermissionStatus? = nil
    )
        -> PermissionsClient
    {
        PermissionsClient(
            status: { _ in status },
            request: { _ in onRequest ?? status },
            openSettings: { _ in }
        )
    }
}
