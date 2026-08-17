import Testing

@testable import ApaceCore

@Suite("Transcription language")
struct TranscriptionLanguageTests {
    @Test("Automatic detection has no forced language code")
    func automatic() {
        #expect(TranscriptionLanguage.automatic.code == nil)
    }

    @Test("Portuguese exposes its recognizer code")
    func portuguese() {
        #expect(TranscriptionLanguage.portuguese.code == "pt")
        #expect(!TranscriptionLanguage.portuguese.displayName.isEmpty)
    }
}
