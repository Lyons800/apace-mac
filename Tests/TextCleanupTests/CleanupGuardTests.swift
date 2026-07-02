import Testing

@testable import TextCleanup

@Suite("Cleanup guard")
struct CleanupGuardTests {
    @Test("Keeps a genuine cleanup")
    func keepsCleanup() {
        let result = CleanupGuard.preserve(
            original: "um does this work",
            cleaned: "Does this work?"
        )
        #expect(result == "Does this work?")
    }

    @Test("Rejects an answer that replaced the words")
    func rejectsAnswer() {
        let result = CleanupGuard.preserve(
            original: "does this work",
            cleaned: "Yes, it works."
        )
        #expect(result == "does this work")
    }

    @Test("Falls back to the original when cleanup comes back empty")
    func rejectsEmpty() {
        let result = CleanupGuard.preserve(original: "hello there friend", cleaned: "   ")
        #expect(result == "hello there friend")
    }

    @Test("Leaves very short input to the model")
    func shortInput() {
        let result = CleanupGuard.preserve(original: "hi", cleaned: "Hello!")
        #expect(result == "Hello!")
    }

    @Test("Strips a chatty preamble")
    func stripsPreamble() {
        let result = CleanupGuard.preserve(
            original: "does this work",
            cleaned: "Sure! Here's a cleaned-up version of your text: Does this work?"
        )
        #expect(result == "Does this work?")
    }

    @Test("Strips a preamble on its own line")
    func stripsPreambleNewline() {
        let result = CleanupGuard.stripPreamble("Here is the cleaned text:\n\nDoes this work?")
        #expect(result == "Does this work?")
    }

    @Test("Leaves a genuine colon alone")
    func keepsRealColon() {
        let result = CleanupGuard.stripPreamble("Meeting notes: buy milk and eggs")
        #expect(result == "Meeting notes: buy milk and eggs")
    }

    @Test("Strips wrapping quotes")
    func stripsQuotes() {
        let result = CleanupGuard.stripPreamble("\"Does this work?\"")
        #expect(result == "Does this work?")
    }
}
