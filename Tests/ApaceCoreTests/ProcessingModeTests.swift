import Testing

@testable import ApaceCore

@Suite("Processing mode")
struct ProcessingModeTests {
    @Test("On-device is the default")
    func defaultMode() {
        #expect(ProcessingMode.default == .onDevice)
    }

    @Test("Each mode recommends a matching cleanup provider")
    func recommendedProviders() {
        #expect(ProcessingMode.onDevice.recommendedCleanupProvider == .onDevice)
        #expect(ProcessingMode.cloud.recommendedCleanupProvider.requiresAPIKey)
    }
}
