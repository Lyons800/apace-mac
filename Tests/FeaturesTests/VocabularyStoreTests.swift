import ApaceClients
import ApaceCore
import Testing

@testable import Features

@MainActor
@Suite("Vocabulary store")
struct VocabularyStoreTests {
    @Test("Learns the recogniser hypothesis as an acoustic alias")
    func learnsHypothesis() async {
        let previous = VocabularyPreference.vocabulary
        defer { VocabularyPreference.vocabulary = previous }

        let entry = VocabularyEntry(term: "Oisin", pronunciation: "uh sheen")
        VocabularyPreference.vocabulary = Vocabulary(entries: [entry])
        let store = VocabularyStore(
            learner: PronunciationLearningClient(
                start: {},
                finish: { "Ashin." },
                cancel: {}
            )
        )

        store.toggleLearning(entry)
        #expect(store.recordingEntryID == entry.id)
        store.toggleLearning(entry)
        #expect(await waitForLearningToFinish(store))

        #expect(store.entries[0].aliases.contains("Ashin"))
        #expect(store.learningMessage == "Learned from “Ashin”.")
    }

    @Test("Does not duplicate an alias the recogniser already learned")
    func avoidsDuplicateAlias() async {
        let previous = VocabularyPreference.vocabulary
        defer { VocabularyPreference.vocabulary = previous }

        let entry = VocabularyEntry(term: "Oisin", pronunciation: "Ashin")
        VocabularyPreference.vocabulary = Vocabulary(entries: [entry])
        let store = VocabularyStore(
            learner: PronunciationLearningClient(
                start: {},
                finish: { "ashin" },
                cancel: {}
            )
        )

        store.toggleLearning(entry)
        store.toggleLearning(entry)
        #expect(await waitForLearningToFinish(store))
        #expect(store.entries[0].pronunciation == "Ashin")
    }
}

@MainActor
private func waitForLearningToFinish(_ store: VocabularyStore) async -> Bool {
    for _ in 0..<200 {
        if store.processingEntryID == nil { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return store.processingEntryID == nil
}
