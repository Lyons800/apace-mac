import ApaceClients
import ApaceCore

public extension HotkeyClient {
    /// Global hotkey via a session-level `CGEvent` tap (requires Accessibility +
    /// Input Monitoring). The adapter owns the robustness work: re-enabling a tap
    /// the system disables, a watchdog for sleep/wake, and a flags-snapshot resync
    /// so recording can never get stuck "on" after a missed key-up.
    ///
    /// - Note: Implemented in milestone M1. Placeholder for now.
    static let live = HotkeyClient(intents: { AsyncStream { $0.finish() } })
}

public extension TextInserterClient {
    /// Inserts text into the frontmost app. Primary path is pasteboard + synthetic
    /// ⌘V (the only broadly-reliable method); falls back to the Accessibility API and
    /// synthetic keystrokes, and guards against Secure Event Input.
    ///
    /// - Note: Implemented in milestone M1. Placeholder for now.
    static let live = TextInserterClient(insert: { _ in })
}
