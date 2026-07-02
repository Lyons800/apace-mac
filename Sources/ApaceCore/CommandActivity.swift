/// What command mode is doing right now, for the notch to reflect. Separate from
/// ``DictationState`` because a command doesn't insert text — it listens, thinks, then
/// shows an answer.
public enum CommandActivity: Equatable, Sendable {
    case idle
    /// Capturing the spoken command; the live transcript follows.
    case listening(partial: String)
    /// The model is working on the answer (optionally looking at the screen).
    case thinking
    /// The answer to show in the notch.
    case answer(String)
    case failed(String)

    public var isActive: Bool { self != .idle }
}
