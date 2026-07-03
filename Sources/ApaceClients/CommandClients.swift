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

/// Everything the command coordinator needs, grouped so the app wires it in one place.
public struct CommandClients: Sendable {
    public var audio: AudioCaptureClient
    public var transcriber: TranscriberClient
    public var screen: ScreenCaptureClient
    public var vision: VisionClient
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
        automation: AutomationClient,
        hotkey: HotkeyClient,
        confirm: @escaping @Sendable (_ summary: String) async -> Bool
    ) {
        self.audio = audio
        self.transcriber = transcriber
        self.screen = screen
        self.vision = vision
        self.automation = automation
        self.hotkey = hotkey
        self.confirm = confirm
    }
}

/// The user's command-mode preferences: whether it's on, whether it may look at the
/// screen, and which provider answers.
public enum CommandPreference {
    static let enabledKey = "apace.commandModeEnabled"
    static let visionKey = "apace.commandVisionEnabled"
    static let providerKey = "apace.visionProvider"
    static let controlKey = "apace.commandControlEnabled"

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
