import Foundation
import Testing

@testable import ApaceCore

@Suite("History entry")
struct HistoryEntryTests {
    @Test("Round-trips through JSON so it can be persisted")
    func codableRoundTrip() throws {
        let entry = HistoryEntry(text: "hello world", date: Date(timeIntervalSince1970: 1_000))
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)
        #expect(decoded == entry)
    }
}
