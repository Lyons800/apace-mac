import Foundation
import Testing

@testable import ApaceCore

@Suite("Recognition vocabulary")
struct VocabularyTests {
    @Test("Produces canonical context and a Whisper decoder prompt")
    func recognitionContext() {
        let vocabulary = Vocabulary(entries: [
            VocabularyEntry(term: "Oisin", pronunciation: "uh sheen, oh sheen"),
            VocabularyEntry(term: "GitHub"),
            VocabularyEntry(term: "   "),
        ])

        #expect(vocabulary.contextualStrings == ["Oisin", "GitHub"])
        #expect(vocabulary.decoderPrompt == "Names and terms: Oisin, GitHub.")
        #expect(
            vocabulary.activeEntries[0].aliases
                == ["uh sheen", "oh sheen"]
        )
    }

    @Test("An empty vocabulary provides no decoder prompt")
    func emptyContext() {
        #expect(Vocabulary().contextualStrings.isEmpty)
        #expect(Vocabulary().decoderPrompt == nil)
    }

    @Test("Migrates the old replacement format without losing saved names")
    func migratesLegacyEntries() throws {
        let json = """
            {
              "entries": [
                {"id":"00000000-0000-0000-0000-000000000001","spoken":"oisin","written":"Oisín"},
                {"id":"00000000-0000-0000-0000-000000000002","spoken":"github","written":"GitHub"},
                {"id":"00000000-0000-0000-0000-000000000003","spoken":"git hub","written":"GitHub"}
              ]
            }
            """

        let vocabulary = try JSONDecoder().decode(Vocabulary.self, from: Data(json.utf8))

        #expect(vocabulary.entries[0].term == "Oisín")
        #expect(vocabulary.entries[0].aliases == ["oisin"])
        #expect(vocabulary.entries[1].term == "GitHub")
        #expect(vocabulary.entries[1].aliases.isEmpty)
        #expect(vocabulary.entries[2].aliases == ["git hub"])
    }

    @Test("New entries encode using recognition fields only")
    func encodesNewFormat() throws {
        let data = try JSONEncoder().encode(
            Vocabulary(entries: [VocabularyEntry(term: "Oisin", pronunciation: "uh sheen")])
        )
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try #require(object["entries"] as? [[String: Any]])

        #expect(entries[0]["term"] as? String == "Oisin")
        #expect(entries[0]["pronunciation"] as? String == "uh sheen")
        #expect(entries[0]["spoken"] == nil)
        #expect(entries[0]["written"] == nil)
    }
}
