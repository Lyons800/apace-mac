import Foundation

/// Gates unfinished features (command mode, Mac control) out of the shipped UI. Off by
/// default, so a fresh install is core dictation only; a developer can reveal them with
/// `defaults write so.apace apace.experimental -bool true`.
public enum ExperimentalPreference {
    static let key = "apace.experimental"

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
