import Foundation
import Testing

@testable import ApaceCore

@Suite("History entry")
struct HistoryEntryTests {
    @Test("Round-trips through JSON so it can be persisted")
    func codableRoundTrip() throws {
        let entry = HistoryEntry(
            text: "hello world",
            date: Date(timeIntervalSince1970: 1_000),
            rawText: "hello world",
            status: .copiedToClipboard,
            errorMessage: "Paste was blocked",
            hasAudio: true
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test("Decodes history written by older Apace releases")
    func decodesLegacyEntry() throws {
        let id = UUID()
        let json = """
            {"id":"\(id.uuidString)","text":"legacy","date":1000}
            """
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: Data(json.utf8))
        #expect(decoded.status == .inserted)
        #expect(decoded.text == "legacy")
        #expect(decoded.hasAudio == false)
    }
}
