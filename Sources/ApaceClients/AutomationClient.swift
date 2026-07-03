import ApaceCore

/// Callbacks the automation loop uses to report progress and ask permission, supplied by
/// whoever runs a command. Keeping confirmation as an injected closure means the loop
/// never needs to know about the notch or the UI — it just asks, and waits.
public struct AutomationHandler: Sendable {
    /// Called on every progress transition.
    public var onStep: @Sendable (AutomationStep) -> Void
    /// Asked before a risky/outward action; returns whether the user approved.
    public var confirm: @Sendable (_ summary: String) async -> Bool

    public init(
        onStep: @escaping @Sendable (AutomationStep) -> Void,
        confirm: @escaping @Sendable (_ summary: String) async -> Bool
    ) {
        self.onStep = onStep
        self.confirm = confirm
    }
}

/// Runs a spoken goal to completion by driving the Mac (the computer-use loop). Behind a
/// port so command mode depends only on this, not on the model or the event injection.
public struct AutomationClient: Sendable {
    public var run: @Sendable (_ goal: String, _ handler: AutomationHandler) async -> Void

    public init(
        run: @escaping @Sendable (_ goal: String, _ handler: AutomationHandler) async -> Void
    ) {
        self.run = run
    }
}
