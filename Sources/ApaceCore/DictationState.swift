import Foundation

/// The lifecycle of a single dictation, from the user triggering the hotkey to the
/// transcribed text landing in the frontmost app.
///
/// This is deliberately a small, pure value type with no knowledge of audio
/// hardware, speech engines, or the UI. That keeps the whole flow — including the
/// tricky ordering of start/stop/partial/final events — drivable and assertable in
/// tests without any system services (see ``DictationStateMachine``).
public enum DictationState: Equatable, Sendable {
    /// Waiting for the user to start a dictation.
    case idle

    /// Recording. `partial` is the latest *volatile* transcript shown live in the
    /// notch overlay. It is a preview only and is never the text that gets inserted.
    case listening(partial: String)

    /// Recording has stopped; the accurate, final transcription pass is running.
    case transcribing

    /// Placing the finished `text` into the frontmost application.
    case inserting(text: String)

    /// A recoverable failure. `message` is safe to show the user.
    case failed(message: String)
}

/// Inputs that can move a dictation between states. They originate from the hotkey
/// layer (`start`/`stop`/`cancel`) and the transcription pipeline (`partial`/`final`).
public enum DictationEvent: Sendable {
    case startRequested
    case partialTranscript(String)
    case stopRequested
    case finalTranscript(String)
    case textInserted
    case cancelled
    case failed(String)
}

/// A pure reducer over ``DictationState``. Given the current state and an event it
/// returns the next state, ignoring events that don't apply to the current state
/// (which makes it robust to the out-of-order delivery that real audio/ML pipelines
/// produce). Holding the transition rules in one pure function is what lets us prove
/// the flow correct in unit tests.
public struct DictationStateMachine: Sendable {
    public init() {}

    public func reduce(_ state: DictationState, on event: DictationEvent) -> DictationState {
        switch (state, event) {
        case (.idle, .startRequested),
            (.failed, .startRequested):
            return .listening(partial: "")

        case (.listening, .partialTranscript(let text)):
            return .listening(partial: text)

        case (.listening, .stopRequested):
            return .transcribing

        case (.transcribing, .finalTranscript(let text)):
            // An empty final pass (silence, hallucination) has nothing to insert.
            return text.isEmpty ? .idle : .inserting(text: text)

        case (.inserting, .textInserted):
            return .idle

        case (.listening, .cancelled),
            (.transcribing, .cancelled),
            (.inserting, .cancelled):
            return .idle

        case (_, .failed(let message)):
            return .failed(message: message)

        default:
            // Out-of-order or irrelevant event for this state — ignore it.
            return state
        }
    }
}
