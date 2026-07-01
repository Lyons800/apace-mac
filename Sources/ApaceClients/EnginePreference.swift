import ApaceCore
import Foundation

/// Reads and writes the user's chosen transcription engine.
///
/// A tiny seam over `UserDefaults` so the transcriber can resolve the current engine
/// per call (from any thread — `UserDefaults` is thread-safe) while the settings UI
/// writes the choice. Defaults to ``TranscriptionEngine/default`` until the user picks.
public enum EnginePreference {
    static let key = "apace.transcriptionEngine"

    public static var engine: TranscriptionEngine {
        get {
            UserDefaults.standard.string(forKey: key)
                .flatMap(TranscriptionEngine.init(rawValue:)) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
