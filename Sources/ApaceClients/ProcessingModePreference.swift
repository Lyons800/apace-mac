import ApaceCore
import Foundation

/// Persists the user's on-device-vs-cloud stance. A thin `UserDefaults` seam, matching
/// the other preferences.
public enum ProcessingModePreference {
    static let key = "apace.processingMode"

    public static var mode: ProcessingMode {
        get {
            UserDefaults.standard.string(forKey: key)
                .flatMap(ProcessingMode.init(rawValue:)) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
