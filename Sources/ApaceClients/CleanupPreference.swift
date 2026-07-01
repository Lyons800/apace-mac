import Foundation

/// Whether AI cleanup runs on a finished transcript. Off by default — cleanup rewrites
/// the user's words with a model, so they opt in. A tiny Sendable seam so the processor
/// can check it per dictation while settings toggles it.
public enum CleanupPreference {
    static let key = "apace.aiCleanupEnabled"

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
