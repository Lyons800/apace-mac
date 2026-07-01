import ApaceCore
import Foundation

/// Reads and writes the user's custom vocabulary as JSON in `UserDefaults`. A tiny
/// Sendable seam so the text processor can load the current vocabulary per dictation
/// (from any thread) while the settings UI writes edits.
public enum VocabularyPreference {
    static let key = "apace.vocabulary"

    public static var vocabulary: Vocabulary {
        get {
            guard
                let data = UserDefaults.standard.data(forKey: key),
                let decoded = try? JSONDecoder().decode(Vocabulary.self, from: data)
            else { return Vocabulary() }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
