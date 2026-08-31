import ApaceCore
import Foundation

/// Answers a spoken command, optionally with a screenshot of the user's screen. The
/// implementation routes to the chosen ``VisionProvider``; a nil image means "no
/// screen context, just answer the question".
public struct VisionClient: Sendable {
    public var respond: @Sendable (_ question: String, _ image: Data?) async throws -> String

    public init(
        respond: @escaping @Sendable (_ question: String, _ image: Data?) async throws -> String
    ) {
        self.respond = respond
    }
}

/// Captures a screenshot of the main display as PNG data, or nil if capture isn't
/// permitted or fails.
public struct ScreenCaptureClient: Sendable {
    public var capture: @Sendable () -> Data?

    public init(capture: @escaping @Sendable () -> Data?) {
        self.capture = capture
    }
}

/// What the user is focused on right now: the frontmost app and the focused text
/// field's content, read via Accessibility. Everything is optional — reads fail
/// silently on apps with poor AX support, and the router copes with whatever's there.
public struct FocusedField: Equatable, Sendable {
    public var appName: String?
    public var selectedText: String?
    /// The field's full value, capped by the live adapter so a huge document
    /// doesn't blow up the prompt.
    public var text: String?

    public init(appName: String? = nil, selectedText: String? = nil, text: String? = nil) {
        self.appName = appName
        self.selectedText = selectedText
        self.text = text
    }
}

/// Reads the focused UI element via Accessibility, or nil when nothing useful is
/// focused (or the permission is missing).
public struct FocusClient: Sendable {
    public var focusedField: @Sendable () -> FocusedField?

    public init(focusedField: @escaping @Sendable () -> FocusedField?) {
        self.focusedField = focusedField
    }
}

/// Decides — and, for answers and text, fulfills — one spoken command in a single
/// model round trip. Gets the request plus whatever context exists (focused field,
/// screenshot) and returns the decision; throwing falls back to the plain answer path.
public struct CommandRouterClient: Sendable {
    public var route:
        @Sendable (
            _ request: String,
            _ field: FocusedField?,
            _ image: Data?,
            _ conversation: [CommandTurn]
        ) async throws -> CommandDecision

    public init(
        route:
            @escaping @Sendable (
                _ request: String,
                _ field: FocusedField?,
                _ image: Data?,
                _ conversation: [CommandTurn]
            ) async throws -> CommandDecision
    ) {
        self.route = route
    }
}

/// Everything the command coordinator needs, grouped so the app wires it in one place.
public struct CommandClients: Sendable {
    public var audio: AudioCaptureClient
    public var transcriber: TranscriberClient
    public var screen: ScreenCaptureClient
    public var vision: VisionClient
    public var router: CommandRouterClient
    public var focus: FocusClient
    public var inserter: TextInserterClient
    public var control: ComputerControlClient
    public var automation: AutomationClient
    public var hotkey: HotkeyClient
    /// Asks the user to approve a risky control action, supplied by the app so the
    /// coordinator doesn't need any UI knowledge.
    public var confirm: @Sendable (_ summary: String) async -> Bool

    public init(
        audio: AudioCaptureClient,
        transcriber: TranscriberClient,
        screen: ScreenCaptureClient,
        vision: VisionClient,
        router: CommandRouterClient,
        focus: FocusClient,
        inserter: TextInserterClient,
        control: ComputerControlClient,
        automation: AutomationClient,
        hotkey: HotkeyClient,
        confirm: @escaping @Sendable (_ summary: String) async -> Bool
    ) {
        self.audio = audio
        self.transcriber = transcriber
        self.screen = screen
        self.vision = vision
        self.router = router
        self.focus = focus
        self.inserter = inserter
        self.control = control
        self.automation = automation
        self.hotkey = hotkey
        self.confirm = confirm
    }
}

/// Reads the user's command-mode preferences at the moment they're needed. A
/// struct-of-closures over ``CommandPreference`` so the coordinator can be tested
/// without touching `UserDefaults`.
public struct CommandPreferencesReader: Sendable {
    public var isEnabled: @Sendable () -> Bool
    public var controlEnabled: @Sendable () -> Bool
    public var followUpsEnabled: @Sendable () -> Bool
    public var usesVision: @Sendable () -> Bool
    public var provider: @Sendable () -> VisionProvider

    public init(
        isEnabled: @escaping @Sendable () -> Bool,
        controlEnabled: @escaping @Sendable () -> Bool,
        followUpsEnabled: @escaping @Sendable () -> Bool,
        usesVision: @escaping @Sendable () -> Bool,
        provider: @escaping @Sendable () -> VisionProvider
    ) {
        self.isEnabled = isEnabled
        self.controlEnabled = controlEnabled
        self.followUpsEnabled = followUpsEnabled
        self.usesVision = usesVision
        self.provider = provider
    }

    public static let live = CommandPreferencesReader(
        isEnabled: { CommandPreference.isEnabled },
        controlEnabled: { CommandPreference.controlEnabled },
        followUpsEnabled: { CommandPreference.followUpsEnabled },
        usesVision: { CommandPreference.usesVision },
        provider: { CommandPreference.provider }
    )
}

/// The user's command-mode preferences: whether it's on, whether it may look at the
/// screen, and which provider answers.
public enum CommandPreference {
    static let enabledKey = "apace.commandModeEnabled"
    static let visionKey = "apace.commandVisionEnabled"
    static let providerKey = "apace.visionProvider"
    static let controlKey = "apace.commandControlEnabled"
    static let followUpsKey = "apace.commandFollowUpsEnabled"

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Whether a command may drive the Mac (the computer-use loop) rather than only
    /// answering. Off by default — it moves the mouse and types.
    public static var controlEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: controlKey) }
        set { UserDefaults.standard.set(newValue, forKey: controlKey) }
    }

    /// Follow-ups are on by default. The conversation is memory-only, bounded, and
    /// expires after inactivity; users can turn this off for isolated commands.
    public static var followUpsEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: followUpsKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: followUpsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: followUpsKey) }
    }

    public static var usesVision: Bool {
        get { UserDefaults.standard.bool(forKey: visionKey) }
        set { UserDefaults.standard.set(newValue, forKey: visionKey) }
    }

    public static var provider: VisionProvider {
        get {
            UserDefaults.standard.string(forKey: providerKey)
                .flatMap(VisionProvider.init(rawValue:)) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }
}
