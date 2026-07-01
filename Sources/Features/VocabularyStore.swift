import ApaceClients
import ApaceCore
import Observation

/// The observable store behind the custom-vocabulary settings. It holds the entries
/// for the UI to edit and writes every change straight back through
/// ``VocabularyPreference``, so a new correction applies to the next dictation.
@Observable
public final class VocabularyStore {
    public var entries: [VocabularyEntry] {
        didSet { VocabularyPreference.vocabulary = Vocabulary(entries: entries) }
    }

    public init() {
        entries = VocabularyPreference.vocabulary.entries
    }

    /// Adds a blank correction for the user to fill in. Empty entries are ignored when
    /// the vocabulary is applied, so a half-finished row is harmless.
    public func add() {
        entries.append(VocabularyEntry(spoken: "", written: ""))
    }

    public func remove(_ entry: VocabularyEntry) {
        entries.removeAll { $0.id == entry.id }
    }
}
