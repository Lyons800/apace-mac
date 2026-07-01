import ApaceClients
import ApaceCore
import Observation

/// The observable store behind the history window. It loads recent dictations from
/// ``TranscriptHistory`` and refreshes on demand, since new entries are appended by the
/// pipeline while the window is closed.
@Observable
public final class HistoryModel {
    public private(set) var entries: [HistoryEntry] = []

    public init() {
        refresh()
    }

    public func refresh() {
        entries = TranscriptHistory.entries
    }

    public func clear() {
        TranscriptHistory.clear()
        entries = []
    }
}
