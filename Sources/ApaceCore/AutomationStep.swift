/// Progress from the computer-use loop, for the notch to show while a command runs.
public enum AutomationStep: Sendable, Equatable {
    /// The model is deciding the next action.
    case thinking
    /// An action is being carried out, described for a human ("Clicking Send…").
    case acting(String)
    /// The task finished; the string is a short summary.
    case done(String)
    case failed(String)
}
