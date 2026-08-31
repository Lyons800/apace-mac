import ApaceCore
import Foundation

/// Stores recent dictations locally, newest first, capped so it can't grow unbounded.
/// Failed/in-flight dictations also keep a temporary Float32 audio buffer in Application
/// Support so a crash or transcription error is recoverable. Successful transcription
/// deletes that audio immediately; raw and processed text remain local.
public enum TranscriptHistory {
    static let key = "apace.history"
    static let limit = 200
    private static let lock = NSLock()

    public static var entries: [HistoryEntry] {
        lock.withLock { loadEntries() }
    }

    private static func loadEntries() -> [HistoryEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return [] }
        return decoded
    }

    public static func append(_ entry: HistoryEntry) {
        lock.withLock { saveAppending(entry) }
    }

    /// Creates the durable record before transcription begins. The audio file is the
    /// recovery boundary: if the app exits after this returns, History can retry it.
    @discardableResult
    public static func begin(samples: [Float], date: Date = Date()) -> UUID {
        let id = UUID()
        let savedAudio = writeAudio(samples, id: id)
        let entry = HistoryEntry(
            id: id,
            text: "",
            date: date,
            status: .processing,
            errorMessage: nil,
            hasAudio: savedAudio
        )
        lock.withLock { saveAppending(entry) }
        return id
    }

    public static func update(
        id: UUID,
        rawText: String? = nil,
        text: String? = nil,
        status: HistoryEntryStatus? = nil,
        errorMessage: String? = nil,
        discardAudio: Bool = false
    ) {
        lock.withLock {
            var updated = loadEntries()
            guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
            if let rawText { updated[index].rawText = rawText }
            if let text { updated[index].text = text }
            if let status { updated[index].status = status }
            updated[index].errorMessage = errorMessage
            if discardAudio {
                removeAudio(id: id)
                updated[index].hasAudio = false
            }
            save(updated)
        }
    }

    public static func entry(id: UUID) -> HistoryEntry? {
        lock.withLock { loadEntries().first(where: { $0.id == id }) }
    }

    public static func audioSamples(id: UUID) -> [Float]? {
        guard let data = try? Data(contentsOf: audioURL(id: id)), !data.isEmpty else { return nil }
        guard data.count.isMultiple(of: MemoryLayout<Float>.size) else { return nil }
        var samples = [Float](
            repeating: 0,
            count: data.count / MemoryLayout<Float>.size
        )
        _ = samples.withUnsafeMutableBytes { destination in
            data.copyBytes(to: destination)
        }
        return samples
    }

    public static func removeAudio(id: UUID) {
        try? FileManager.default.removeItem(at: audioURL(id: id))
    }

    private static func saveAppending(_ entry: HistoryEntry) {
        var updated = loadEntries()
        updated.insert(entry, at: 0)
        if updated.count > limit {
            let removed = updated.dropFirst(limit)
            for entry in removed { removeAudio(id: entry.id) }
            updated = Array(updated.prefix(limit))
        }
        save(updated)
    }

    private static func save(_ updated: [HistoryEntry]) {
        guard let data = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    public static func clear() {
        lock.withLock {
            for entry in loadEntries() { removeAudio(id: entry.id) }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func writeAudio(_ samples: [Float], id: UUID) -> Bool {
        guard !samples.isEmpty else { return false }
        do {
            try FileManager.default.createDirectory(
                at: audioDirectory,
                withIntermediateDirectories: true
            )
            let data = samples.withUnsafeBytes { Data($0) }
            try data.write(to: audioURL(id: id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static var audioDirectory: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Apace/Recovery", isDirectory: true)
    }

    private static func audioURL(id: UUID) -> URL {
        audioDirectory.appendingPathComponent("\(id.uuidString).f32")
    }
}
