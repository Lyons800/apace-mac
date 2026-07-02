import Foundation

/// A safety net for AI cleanup. Cleanup should only tidy the words the user said, but a
/// model can misbehave two ways: it can *answer* a dictated question ("Does this work?"
/// → "Yes, it works.") or wrap the result in a chatty preamble ("Sure, here's the
/// cleaned text: …"). We strip a leading preamble, then reject any result that shares
/// too few words with the transcript, falling back to the untouched text.
enum CleanupGuard {
    private static let filler: Set<String> = [
        "um", "uh", "er", "ah", "like", "you", "know", "so", "well",
    ]

    private static let preambleMarkers = [
        "here's", "here is", "here are", "sure", "certainly", "of course", "cleaned",
        "cleaned-up", "revised", "corrected", "version", "okay", "output",
    ]

    /// Returns `cleaned` if it still resembles what the user said, otherwise `original`.
    static func preserve(original: String, cleaned: String) -> String {
        let trimmed = stripPreamble(cleaned)
        guard !trimmed.isEmpty else { return original }

        // Only judge inputs long enough to measure; short ones are left to the model.
        let originalWords = words(original).filter { !filler.contains($0) }
        guard originalWords.count >= 3 else { return trimmed }

        let cleanedWords = Set(words(trimmed))
        let kept = originalWords.filter { cleanedWords.contains($0) }.count
        let overlap = Double(kept) / Double(originalWords.count)
        return overlap >= 0.5 ? trimmed : original
    }

    /// Drops a leading conversational preamble a model may prepend, and surrounding
    /// quotes. Conservative: only strips a lead-in that actually looks like one, so real
    /// dictated text ("Meeting notes: buy milk") is left alone.
    static func stripPreamble(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // A preamble ending in a colon: "Sure! Here's the cleaned text: <content>".
        if let colon = result.firstIndex(of: ":") {
            let lead = result[result.startIndex..<colon].lowercased()
            let wordCount = lead.split { !$0.isLetter }.count
            if wordCount <= 12, preambleMarkers.contains(where: { lead.contains($0) }) {
                result = String(result[result.index(after: colon)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strip matching wrapping quotes the model sometimes adds.
        for quote in ["\"", "'", "“"] where result.hasPrefix(quote) {
            result = String(result.dropFirst())
        }
        for quote in ["\"", "'", "”"] where result.hasSuffix(quote) {
            result = String(result.dropLast())
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}
