import ApaceCore
import Foundation

/// Persists the language hint independently of the selected engine so it follows the
/// user when they compare Parakeet, Whisper, and Apple Speech.
public enum SpeechLanguagePreference {
    static let key = "apace.transcriptionLanguage"

    public static var language: TranscriptionLanguage {
        get {
            UserDefaults.standard.string(forKey: key)
                .flatMap(TranscriptionLanguage.init(rawValue:)) ?? .automatic
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
