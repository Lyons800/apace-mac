import ApaceClients
import ApaceCore
import Testing

@testable import Features

@MainActor
@Suite("Permissions model")
struct PermissionsModelTests {
    @Test("Reads each permission's status on load")
    func readsStatuses() {
        let model = PermissionsModel(client: .stub(.notDetermined))
        #expect(model.status(.microphone) == .notDetermined)
        #expect(model.allGranted == false)
    }

    @Test("All-granted is true only when every permission is granted")
    func allGranted() {
        #expect(PermissionsModel(client: .stub(.granted)).allGranted)
    }

    @Test("Requesting a permission records the returned status")
    func requestRecordsResult() async {
        let model = PermissionsModel(client: .stub(.notDetermined, onRequest: .granted))
        await model.request(.microphone)
        #expect(model.status(.microphone) == .granted)
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
