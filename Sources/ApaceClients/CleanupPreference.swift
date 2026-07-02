import ApaceCore
import Foundation

/// The user's AI-cleanup preferences: whether it runs, and which provider does it. Off
/// by default — cleanup rewrites the user's words with a model, so they opt in — and
/// on-device by default when they do. A tiny Sendable seam over `UserDefaults` so the
/// processor can read the choice per dictation.
public enum CleanupPreference {
    static let enabledKey = "apace.aiCleanupEnabled"
    static let providerKey = "apace.cleanupProvider"

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    public static var provider: CleanupProvider {
        get {
            UserDefaults.standard.string(forKey: providerKey)
                .flatMap(CleanupProvider.init(rawValue:)) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }
}
