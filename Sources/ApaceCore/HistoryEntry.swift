import Foundation

/// One past dictation: the text that was inserted and when. Kept as a small value type
/// so history can be persisted and shown without the UI knowing where it's stored.
public struct HistoryEntry: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public let text: String
    public let date: Date

    public init(id: UUID = UUID(), text: String, date: Date) {
        self.id = id
        self.text = text
        self.date = date
    }
}
