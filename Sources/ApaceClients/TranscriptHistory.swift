import ApaceCore
import Foundation

/// Stores recent dictations locally, newest first, capped so it can't grow unbounded.
/// A tiny seam over `UserDefaults` — the pipeline appends, the history UI reads.
/// Everything stays on the device.
public enum TranscriptHistory {
    static let key = "apace.history"
    static let limit = 200

    public static var entries: [HistoryEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return [] }
        return decoded
    }

    public static func append(_ entry: HistoryEntry) {
        var updated = entries
        updated.insert(entry, at: 0)
        if updated.count > limit {
            updated = Array(updated.prefix(limit))
        }
        guard let data = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
