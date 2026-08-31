/// The physical modifier Apace watches globally. Keeping this as a domain value makes
/// the choice persistable and keeps Carbon key codes out of the settings UI.
public enum DictationActivationKey: String, CaseIterable, Sendable {
    case rightOption
    case leftOption
    case rightControl
    case leftControl
    case function

    public var displayName: String {
        switch self {
        case .rightOption: "Right Option"
        case .leftOption: "Left Option"
        case .rightControl: "Right Control"
        case .leftControl: "Left Control"
        case .function: "Fn"
        }
    }
}

public enum DictationShortcutMode: String, CaseIterable, Sendable {
    case pushToTalk
    case handsFree

    public var displayName: String {
        switch self {
        case .pushToTalk: "Hold to talk"
        case .handsFree: "Press to start or stop"
        }
    }
}

public enum DictationCancelShortcut: String, CaseIterable, Sendable {
    case escape
    case commandPeriod

    public var displayName: String {
        switch self {
        case .escape: "Escape"
        case .commandPeriod: "Command-Period"
        }
    }
}
