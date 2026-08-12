import Foundation

/// A name or specialist term the speech recogniser should prefer while decoding.
/// `pronunciation` is a comma-separated list of likely phonetic renderings, such as
/// "uh sheen, oh sheen" for "Oisin". These are recognition hints, never find-and-
/// replace rules.
public struct VocabularyEntry: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public var term: String
    public var pronunciation: String

    public init(id: UUID = UUID(), term: String, pronunciation: String = "") {
        self.id = id
        self.term = term
        self.pronunciation = pronunciation
    }

    /// Clean pronunciation variants for recognisers that support aliases.
    public var aliases: [String] {
        pronunciation
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: (items: [String](), seen: Set<String>())) { result, hint in
                if result.seen.insert(hint.lowercased()).inserted {
                    result.items.append(hint)
                }
            }.items
    }

    private enum CodingKeys: String, CodingKey {
        case id, term, pronunciation
        // v0.1 used post-transcription `spoken → written` replacements. Decode those
        // keys once so existing users keep their saved names when upgrading.
        case spoken, written
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()

        if let term = try values.decodeIfPresent(String.self, forKey: .term) {
            self.term = term
            pronunciation = try values.decodeIfPresent(String.self, forKey: .pronunciation) ?? ""
            return
        }

        let spoken = try values.decodeIfPresent(String.self, forKey: .spoken) ?? ""
        let written = try values.decodeIfPresent(String.self, forKey: .written) ?? ""
        term = written.isEmpty ? spoken : written
        pronunciation = spoken.caseInsensitiveCompare(term) == .orderedSame ? "" : spoken
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(term, forKey: .term)
        try values.encode(pronunciation, forKey: .pronunciation)
    }
}

/// The user's recognition vocabulary. Engines consume this before or during decoding:
/// Apple Speech receives contextual strings, Whisper receives prompt tokens, and
/// Parakeet receives weighted custom-vocabulary terms with acoustic CTC rescoring.
public struct Vocabulary: Sendable, Equatable, Codable {
    public var entries: [VocabularyEntry]

    public init(entries: [VocabularyEntry] = []) {
        self.entries = entries
    }

    public var activeEntries: [VocabularyEntry] {
        entries.compactMap { entry in
            var cleaned = entry
            cleaned.term = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.term.isEmpty ? nil : cleaned
        }
    }

    /// Canonical spellings suitable for recognisers with a text context API.
    public var contextualStrings: [String] {
        activeEntries.map(\.term)
    }

    /// A short prior-transcript prompt for Whisper's decoder.
    public var decoderPrompt: String? {
        let terms = contextualStrings
        guard !terms.isEmpty else { return nil }
        return "Names and terms: " + terms.joined(separator: ", ") + "."
    }
}
