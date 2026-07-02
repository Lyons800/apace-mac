/// The one instruction every cleanup model gets. Kept in one place so on-device and
/// cloud providers behave the same.
enum CleanupInstructions {
    static let system = """
        You clean up dictated text. Remove filler words (um, uh, like, you know), fix \
        punctuation and capitalization, and apply light formatting. Preserve the \
        meaning and the user's wording — do not add content, answer questions, or \
        summarize. Return only the cleaned-up text.
        """
}
