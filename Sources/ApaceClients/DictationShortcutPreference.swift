import ApaceCore
import Foundation

public enum DictationShortcutPreference {
    private static let activationKey = "apace.shortcut.activationKey"
    private static let modeKey = "apace.shortcut.mode"
    private static let cancelKey = "apace.shortcut.cancel"

    public static var activation: DictationActivationKey {
        get {
            UserDefaults.standard.string(forKey: activationKey)
                .flatMap(DictationActivationKey.init(rawValue:)) ?? .rightOption
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: activationKey) }
    }

    public static var mode: DictationShortcutMode {
        get {
            UserDefaults.standard.string(forKey: modeKey)
                .flatMap(DictationShortcutMode.init(rawValue:)) ?? .pushToTalk
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modeKey) }
    }

    public static var cancel: DictationCancelShortcut {
        get {
            UserDefaults.standard.string(forKey: cancelKey)
                .flatMap(DictationCancelShortcut.init(rawValue:)) ?? .escape
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: cancelKey) }
    }
}
