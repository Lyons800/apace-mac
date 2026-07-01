import Foundation

/// One custom-vocabulary correction: what the recogniser tends to hear, and what it
/// should have written. Used for names, jargon, and casing the speech model gets wrong
/// ("github" → "GitHub", "oisin" → "Oisín", "kubernetes" → "Kubernetes").
public struct VocabularyEntry: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public var spoken: String
    public var written: String

    public init(id: UUID = UUID(), spoken: String, written: String) {
        self.id = id
        self.spoken = spoken
        self.written = written
    }
}

/// The user's custom vocabulary — a pure, testable value that rewrites a transcript by
/// applying each correction as a whole-word, case-insensitive substitution. It runs
/// on-device with no model or network, so it's private and instant.
public struct Vocabulary: Sendable, Equatable, Codable {
    public var entries: [VocabularyEntry]

    public init(entries: [VocabularyEntry] = []) {
        self.entries = entries
    }

    /// Rewrites `text`, replacing each entry's spoken form (matched on whole words,
    /// ignoring case) with its written form. Entries with an empty spoken form are
    /// skipped so a half-typed correction can't blank out the transcript.
    public func apply(to text: String) -> String {
        entries.reduce(text) { result, entry in
            guard !entry.spoken.isEmpty else { return result }
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: entry.spoken) + "\\b"
            let replacement = NSRegularExpression.escapedTemplate(for: entry.written)
            return result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
    }
}
