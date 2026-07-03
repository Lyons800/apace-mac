import CoreGraphics

/// A single low-level control action — the vocabulary the automation loop speaks to the
/// Mac. It mirrors the actions a computer-use model emits (click, type, key, scroll), so
/// translating the model's output to real input is a direct mapping.
public enum ControlAction: Sendable {
    case moveMouse(CGPoint)
    case click(CGPoint)
    case doubleClick(CGPoint)
    case rightClick(CGPoint)
    /// Types a literal string wherever focus currently is.
    case type(String)
    /// Presses a key with optional modifiers (e.g. Return, or ⌘ + V).
    case key(CGKeyCode, CGEventFlags)
    case scroll(deltaX: Int, deltaY: Int)
}

/// Injects synthetic input into the system — the "hands" of command mode. Executing an
/// action requires the Accessibility permission; without it the events are dropped by
/// the OS. Kept behind a port so the automation logic stays testable without moving the
/// real mouse.
public struct ComputerControlClient: Sendable {
    public var perform: @Sendable (ControlAction) -> Void

    public init(perform: @escaping @Sendable (ControlAction) -> Void) {
        self.perform = perform
    }
}
