import ApaceClients
import ApaceCore

extension HotkeyClient {
    /// Global hotkey via a session-level `CGEvent` tap (requires Accessibility +
    /// Input Monitoring). The adapter owns the robustness work: re-enabling a tap
    /// the system disables, a watchdog for sleep/wake, and a flags-snapshot resync
    /// so recording can never get stuck "on" after a missed key-up.
    ///
    /// - Note: implemented next in milestone M1. Inert placeholder for now.
    public static let live = HotkeyClient(intents: { AsyncStream { $0.finish() } })
}
