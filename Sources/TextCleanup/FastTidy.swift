import ApaceClients
import Foundation

/// An instant, deterministic tidy applied to every transcript — no model, no latency.
/// It removes only *unambiguous* filler words (um, uh, er…) and normalises spacing and
/// the leading capital. Anything context-dependent (rephrasing, ambiguous filler like
/// "like") is left to the optional AI cleanup, so the fast path stays fast. Modern
/// engines already punctuate and capitalize, so this alone gives a clean result.
public enum FastTidy {
    private static let fillers: Set<String> = [
        "um", "umm", "uh", "uhh", "uhm", "er", "err", "erm", "ah", "ahh", "hmm", "mmm",
    ]

    public static func apply(_ text: String) -> String {
        let tokens = text.split { $0 == " " || $0 == "\n" || $0 == "\t" }
        let kept = tokens.filter { token in
            let bare = token.lowercased().trimmingCharacters(
                in: CharacterSet(charactersIn: ",.!?;:")
            )
            return !fillers.contains(bare)
        }

        var result = kept.joined(separator: " ")
        for punctuation in [",", ".", "!", "?", ";", ":"] {
            result = result.replacingOccurrences(of: " \(punctuation)", with: punctuation)
        }
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Removing a leading filler can leave a lower-case first word — fix it.
        if let first = result.first, first.isLowercase {
            result.replaceSubrange(
                result.startIndex...result.startIndex,
                with: first.uppercased()
            )
        }
        return result
    }
}

extension TextProcessorClient {
    /// The always-on instant tidy, as a processor client.
    public static let fastTidy = TextProcessorClient { FastTidy.apply($0) }
}
