import Testing

@testable import ApaceCore

@Suite("Vocabulary")
struct VocabularyTests {
    private let vocab = Vocabulary(entries: [
        VocabularyEntry(spoken: "github", written: "GitHub"),
        VocabularyEntry(spoken: "oisin", written: "Oisín"),
    ])

    @Test("Corrects a whole word regardless of case")
    func correctsCasing() {
        #expect(vocab.apply(to: "i pushed to github today") == "i pushed to GitHub today")
        #expect(vocab.apply(to: "Github is down") == "GitHub is down")
    }

    @Test("Only replaces whole words, not substrings")
    func wholeWordsOnly() {
        #expect(vocab.apply(to: "githubbing all night") == "githubbing all night")
    }

    @Test("Applies every entry across the text")
    func appliesAllEntries() {
        #expect(vocab.apply(to: "oisin uses github") == "Oisín uses GitHub")
    }

    @Test("Handles multi-word spoken forms")
    func multiWord() {
        let v = Vocabulary(entries: [VocabularyEntry(spoken: "git hub", written: "GitHub")])
        #expect(v.apply(to: "check git hub") == "check GitHub")
    }

    @Test("Empty vocabulary and empty entries leave the text untouched")
    func leavesTextUntouched() {
        #expect(Vocabulary().apply(to: "nothing to change") == "nothing to change")
        let v = Vocabulary(entries: [VocabularyEntry(spoken: "", written: "X")])
        #expect(v.apply(to: "keep this") == "keep this")
    }
}
