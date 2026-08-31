import Foundation

/// What one spoken command should do, as decided by the intent router. One decision
/// per command: show an answer, put text into the focused field, or hand the whole
/// task to the computer-use loop.
public enum CommandDecision: Equatable, Sendable {
    /// Show this text in the notch.
    case answer(String)
    /// Paste this text into the focused field. When `replacesDraft` is true the
    /// field's current content is selected first, so a transformed draft (a
    /// translation, a rewrite) replaces the original instead of appending to it.
    case insert(text: String, replacesDraft: Bool)
    /// A multi-step task that needs to drive the Mac. `goal` is self-contained after the
    /// router resolves follow-up phrases such as "send it" against recent conversation.
    case control(goal: String, risk: CommandActionRisk)
}
