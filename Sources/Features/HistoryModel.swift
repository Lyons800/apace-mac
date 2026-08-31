import ApaceClients
import ApaceCore
import Foundation
import Observation

/// The observable store behind the history window. It loads recent dictations from
/// ``TranscriptHistory`` and refreshes on demand, since new entries are appended by the
/// pipeline while the window is closed.
@Observable
public final class HistoryModel {
    public private(set) var entries: [HistoryEntry] = []
    public private(set) var retryingID: UUID?
    public private(set) var recoveryMessage: String?

    private let retryEntry: @Sendable (UUID) async -> Bool

    public init(retryEntry: @escaping @Sendable (UUID) async -> Bool = { _ in false }) {
        self.retryEntry = retryEntry
        refresh()
    }

    public func refresh() {
        entries = TranscriptHistory.entries
    }

    public func clear() {
        TranscriptHistory.clear()
        entries = []
    }

    public func retry(_ entry: HistoryEntry) {
        guard retryingID == nil else { return }
        retryingID = entry.id
        recoveryMessage = nil
        Task { [weak self] in
            guard let self else { return }
            let recovered = await retryEntry(entry.id)
            refresh()
            retryingID = nil
            recoveryMessage =
                recovered ? "Dictation recovered and inserted." : "Recovery did not insert text."
        }
    }
}
