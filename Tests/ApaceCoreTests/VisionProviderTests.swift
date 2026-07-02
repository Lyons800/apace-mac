import Testing

@testable import ApaceCore

@Suite("Vision provider & command activity")
struct VisionProviderTests {
    @Test("On-device is the default and needs no key")
    func defaultProvider() {
        #expect(VisionProvider.default == .onDevice)
        #expect(!VisionProvider.onDevice.requiresAPIKey)
        #expect(VisionProvider.gemini.requiresAPIKey)
    }

    @Test("The mode recommends a matching vision provider")
    func recommended() {
        #expect(VisionProvider.recommended(for: .onDevice) == .onDevice)
        #expect(VisionProvider.recommended(for: .cloud) == .gemini)
    }

    @Test("Command activity knows when it's on screen")
    func activity() {
        #expect(!CommandActivity.idle.isActive)
        #expect(CommandActivity.thinking.isActive)
        #expect(CommandActivity.answer("hi").isActive)
    }
}
