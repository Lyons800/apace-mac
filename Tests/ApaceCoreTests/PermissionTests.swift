import Testing

@testable import ApaceCore

@Suite("Permissions")
struct PermissionTests {
    @Test("Every permission has a title and a rationale to show the user")
    func copyIsPresent() {
        for permission in Permission.allCases {
            #expect(!permission.title.isEmpty)
            #expect(!permission.rationale.isEmpty)
        }
    }

    @Test("Dictation and the hotkey are all covered")
    func coversTheStack() {
        #expect(Permission.allCases.contains(.microphone))
        #expect(Permission.allCases.contains(.speechRecognition))
        #expect(Permission.allCases.contains(.accessibility))
    }
}
