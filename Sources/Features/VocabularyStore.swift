import ApaceClients
import ApaceCore
import Foundation
import Observation

/// The observable store behind recognition vocabulary settings. Every edit is saved
/// immediately, so the speech engines receive the new context on the next dictation.
@Observable
public final class VocabularyStore {
    public var entries: [VocabularyEntry] {
        didSet { VocabularyPreference.vocabulary = Vocabulary(entries: entries) }
    }

    public private(set) var recordingEntryID: UUID?
    public private(set) var processingEntryID: UUID?
    public private(set) var learningMessage: String?

    private let learner: PronunciationLearningClient

    public init(learner: PronunciationLearningClient = .unavailable) {
        self.learner = learner
        entries = VocabularyPreference.vocabulary.entries
    }

    /// Adds a blank recognition term. Engines ignore it until a spelling is entered.
    public func add() {
        entries.append(VocabularyEntry(term: ""))
    }

    public func remove(_ entry: VocabularyEntry) {
        if recordingEntryID == entry.id {
            learner.cancel()
            recordingEntryID = nil
        }
        entries.removeAll { $0.id == entry.id }
    }

    /// Starts a short sample or, on the second click, learns the unbiased spelling the
    /// active recogniser heard. That spelling becomes a narrow acoustic alias.
    public func toggleLearning(_ entry: VocabularyEntry) {
        if recordingEntryID == entry.id {
            recordingEntryID = nil
            processingEntryID = entry.id
            learningMessage = "Learning…"
            Task { await finishLearning(entry.id) }
            return
        }

        if recordingEntryID != nil {
            learner.cancel()
            recordingEntryID = nil
        }

        do {
            try learner.start()
            recordingEntryID = entry.id
            learningMessage =
                "Say only “\(entry.term.isEmpty ? "the name" : entry.term)”, then click Stop."
        } catch {
            learningMessage = "Couldn’t access the microphone."
        }
    }

    private func finishLearning(_ id: UUID) async {
        do {
            let raw = try await learner.finish()
            let heard = raw.trimmingCharacters(
                in: .whitespacesAndNewlines.union(.punctuationCharacters)
            )
            guard !heard.isEmpty else {
                processingEntryID = nil
                learningMessage = "Nothing was heard. Try again and say only the name."
                return
            }
            guard let index = entries.firstIndex(where: { $0.id == id }) else {
                processingEntryID = nil
                return
            }

            if heard.caseInsensitiveCompare(entries[index].term) != .orderedSame,
                !entries[index].aliases.contains(where: {
                    $0.caseInsensitiveCompare(heard) == .orderedSame
                })
            {
                let existing = entries[index].pronunciation.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                entries[index].pronunciation = existing.isEmpty ? heard : "\(existing), \(heard)"
            }
            processingEntryID = nil
            learningMessage = "Learned from “\(heard)”."
        } catch {
            processingEntryID = nil
            learningMessage = "Couldn’t learn that pronunciation. Try again."
        }
    }
}
