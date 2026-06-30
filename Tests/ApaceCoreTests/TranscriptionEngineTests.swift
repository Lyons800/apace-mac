import Testing

@testable import ApaceCore

@Suite("Transcription engine catalog")
struct TranscriptionEngineTests {
    @Test("Every engine has a display name")
    func displayNames() {
        for engine in TranscriptionEngine.allCases {
            #expect(!engine.displayName.isEmpty)
        }
    }

    @Test("Only Apple is available without a model download")
    func modelDownloadRequirement() {
        #expect(TranscriptionEngine.apple.requiresModelDownload == false)
        #expect(TranscriptionEngine.whisper.requiresModelDownload)
        #expect(TranscriptionEngine.parakeet.requiresModelDownload)
    }

    @Test("Apple is the default engine")
    func defaultEngine() {
        #expect(TranscriptionEngine.default == .apple)
    }

    @Test("The selection round-trips through its raw value for persistence")
    func rawValueRoundTrip() {
        for engine in TranscriptionEngine.allCases {
            #expect(TranscriptionEngine(rawValue: engine.rawValue) == engine)
        }
    }
}
