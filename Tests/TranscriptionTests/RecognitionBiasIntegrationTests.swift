import ApaceClients
import ApaceCore
import FluidAudio
import Foundation
import Testing

@testable import Transcription

@Suite("Recognition bias integration")
struct RecognitionBiasIntegrationTests {
    /// Run manually with `APACE_NAME_AUDIO=/path/to/16khz-or-convertible-audio swift test`.
    /// This stays opt-in because it downloads and executes the Parakeet + CTC models.
    @Test("Parakeet acoustically rescores a taught name")
    func parakeetTaughtName() async throws {
        guard let path = ProcessInfo.processInfo.environment["APACE_NAME_AUDIO"] else { return }

        let previous = VocabularyPreference.vocabulary
        VocabularyPreference.vocabulary = Vocabulary(entries: [
            VocabularyEntry(term: "Oisin", pronunciation: "Ashin, uh sheen, oh sheen")
        ])
        defer { VocabularyPreference.vocabulary = previous }

        let samples = try AudioConverter().resampleAudioFile(path: path)
        let text = try await ParakeetEngine.v3.transcribe(samples)

        #expect(text.localizedCaseInsensitiveContains("Oisin"))
        #expect(text == "My name is Oisin and Oisin is joining the meeting.")
    }
}
