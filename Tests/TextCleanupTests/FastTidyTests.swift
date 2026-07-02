import Testing

@testable import TextCleanup

@Suite("Fast tidy")
struct FastTidyTests {
    @Test("Removes standalone filler and fixes the leading capital")
    func removesFiller() {
        #expect(FastTidy.apply("um does this work") == "Does this work")
        #expect(FastTidy.apply("uh, hello there") == "Hello there")
    }

    @Test("Leaves real words that only look like filler alone-ish")
    func keepsRealWords() {
        // "like" and "so" are ambiguous, so the fast pass leaves them for the AI layer.
        #expect(FastTidy.apply("I would like that") == "I would like that")
    }

    @Test("Normalises spacing")
    func normalisesSpacing() {
        #expect(FastTidy.apply("hello    world") == "Hello world")
    }

    @Test("Leaves already-clean text unchanged")
    func cleanText() {
        #expect(FastTidy.apply("Does this work?") == "Does this work?")
    }
}
