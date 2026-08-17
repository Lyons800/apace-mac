import Foundation

/// Classifies Right-Option presses into the two gestures the hotkey drives: a plain
/// press-and-hold dictates, a double-tap-and-hold is a command. Pure state — the hotkey
/// monitor feeds it press/release times and routes the returned intent — so the timing
/// rules are testable without CGEvents.
public struct OptionGesture: Sendable {
    public enum Route: Equatable, Sendable {
        case dictation
        case command
    }

    /// Which stream an intent belongs to, and the intent itself.
    public struct Output: Equatable, Sendable {
        public let route: Route
        public let intent: HotkeyIntent

        public init(route: Route, intent: HotkeyIntent) {
            self.route = route
            self.intent = intent
        }
    }

    /// A press shorter than this counts as a "tap" rather than a hold.
    private let tapMax: TimeInterval
    /// The second tap must begin within this of the first tap's release.
    private let gapMax: TimeInterval

    private var isPressed = false
    private var current: Route?
    private var downTime: TimeInterval = 0
    private var lastUpTime: TimeInterval = -1
    private var lastPressWasTap = false

    public init(tapMax: TimeInterval = 0.25, gapMax: TimeInterval = 0.3) {
        self.tapMax = tapMax
        self.gapMax = gapMax
    }

    public mutating func pressed(at now: TimeInterval) -> Output? {
        guard !isPressed else { return nil }
        isPressed = true
        let isDoubleTap = lastPressWasTap && lastUpTime >= 0 && (now - lastUpTime) < gapMax
        downTime = now
        let route: Route = isDoubleTap ? .command : .dictation
        current = route
        return Output(route: route, intent: .startDictation)
    }

    public mutating func released(at now: TimeInterval) -> Output? {
        guard isPressed, let route = current else { return nil }
        isPressed = false
        current = nil
        let wasTap = (now - downTime) < tapMax
        lastPressWasTap = wasTap
        lastUpTime = now
        switch route {
        case .command:
            return Output(route: .command, intent: .stopDictation)
        case .dictation:
            // A tap may be the first half of a double-tap command, so the dictation that
            // optimistically started is cancelled — never stopped, which would run the
            // transcribe-and-insert path and flash a phantom dictation.
            return Output(route: .dictation, intent: wasTap ? .cancel : .stopDictation)
        }
    }

    /// Abandons the active gesture when the system event stream becomes unreliable.
    /// Recovery always cancels: it must never transcribe or insert a partial recording.
    public mutating func cancelCurrent() -> Output? {
        guard isPressed, let route = current else { return nil }
        isPressed = false
        current = nil
        lastPressWasTap = false
        lastUpTime = -1
        return Output(route: route, intent: .cancel)
    }
}
