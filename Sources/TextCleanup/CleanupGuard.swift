import Foundation

/// A safety net for AI cleanup. Cleanup should only tidy the words the user said — but a
/// model can misbehave and *answer* a dictated question ("Does this work?" → "Yes, it
/// works."). Since a real cleanup keeps almost all of the original words, we reject any
/// result that shares too few of them and fall back to the untouched transcript.
enum CleanupGuard {
    private static let filler: Set<String> = [
        "um", "uh", "er", "ah", "like", "you", "know", "so", "well",
    ]

    /// Returns `cleaned` if it still resembles what the user said, otherwise `original`.
    static func preserve(original: String, cleaned: String) -> String {
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return original }

        // Only judge inputs long enough to measure; short ones are left to the model.
        let originalWords = words(original).filter { !filler.contains($0) }
        guard originalWords.count >= 3 else { return trimmed }

        let cleanedWords = Set(words(trimmed))
        let kept = originalWords.filter { cleanedWords.contains($0) }.count
        let overlap = Double(kept) / Double(originalWords.count)
        return overlap >= 0.5 ? trimmed : original
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}
