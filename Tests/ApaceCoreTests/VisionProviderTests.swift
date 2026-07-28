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

    @Test("Only providers that can see the screen accept a screenshot")
    func supportsImages() {
        // On-device Foundation Models are text-only today, so capturing a screenshot
        // for them is wasted work and a misleading "vision" toggle.
        #expect(!VisionProvider.onDevice.supportsImages)
        #expect(VisionProvider.anthropic.supportsImages)
        #expect(VisionProvider.gemini.supportsImages)
    }

    @Test("Anthropic vision shares the Cleanup key so it's entered once")
    func anthropicKeyShared() {
        #expect(VisionProvider.anthropic.keyAccount == CleanupProvider.anthropic.keyAccount)
    }

    @Test("The mode recommends a matching vision provider")
    func recommended() {
        #expect(VisionProvider.recommended(for: .onDevice) == .onDevice)
        #expect(VisionProvider.recommended(for: .cloud) == .anthropic)
    }

    @Test("Command activity knows when it's on screen")
    func activity() {
        #expect(!CommandActivity.idle.isActive)
        #expect(CommandActivity.thinking.isActive)
        #expect(CommandActivity.answer("hi").isActive)
    }
}
