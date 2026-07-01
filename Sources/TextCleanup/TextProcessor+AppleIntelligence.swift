import ApaceClients
import FoundationModels

extension TextProcessorClient {
    /// On-device AI cleanup via Apple Intelligence (macOS 26+). It removes filler,
    /// fixes punctuation and capitalization, and lightly formats — all on the device,
    /// nothing leaves the Mac. When Apple Intelligence isn't available it returns the
    /// text unchanged, so it's always safe to have in the pipeline.
    public static let appleIntelligence = TextProcessorClient { text in
        await AppleIntelligenceCleaner.clean(text)
    }
}

enum AppleIntelligenceCleaner {
    /// Whether on-device cleanup can actually run here (macOS 26 with Apple
    /// Intelligence enabled). Used to decide whether to fall back to a remote model.
    static var isAvailable: Bool {
        guard #available(macOS 26.0, *) else { return false }
        return SystemLanguageModel.default.isAvailable
    }

    static func clean(_ text: String) async -> String {
        guard !text.isEmpty else { return text }
        guard #available(macOS 26.0, *) else { return text }

        let model = SystemLanguageModel.default
        guard model.isAvailable else { return text }

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: text)
            return response.content
        } catch {
            // Best-effort: never lose the transcript to a cleanup failure.
            return text
        }
    }

    private static let instructions = """
        You clean up dictated text. Remove filler words (um, uh, like, you know), fix \
        punctuation and capitalization, and apply light formatting. Preserve the \
        meaning and the user's wording — do not add content, answer questions, or \
        summarize. Return only the cleaned-up text.
        """
}
