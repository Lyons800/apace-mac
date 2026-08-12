import ApaceCore
import Foundation

/// Reads and writes the user's recognition vocabulary as JSON in `UserDefaults`.
/// Speech engines load it fresh for each dictation while the settings UI writes edits.
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
