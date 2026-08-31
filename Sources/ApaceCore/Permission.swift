/// A system permission Apace needs. Dictation needs the microphone and speech
/// recognition. Input Monitoring allows the global hotkey to listen for the shortcut;
/// Accessibility lets Apace paste into the focused application.
public enum Permission: String, CaseIterable, Sendable {
    case microphone
    case speechRecognition
    case inputMonitoring
    case accessibility

    /// Name shown in onboarding and settings.
    public var title: String {
        switch self {
        case .microphone: "Microphone"
        case .speechRecognition: "Speech Recognition"
        case .inputMonitoring: "Input Monitoring"
        case .accessibility: "Accessibility"
        }
    }

    /// One line explaining why Apace asks for it, in the user's interest.
    public var rationale: String {
        switch self {
        case .microphone:
            "So Apace can hear you. Audio is processed on your Mac and never leaves it."
        case .speechRecognition:
            "So Apace can turn your speech into text, on-device."
        case .inputMonitoring:
            "So Apace can detect your dictation shortcut while you work in another app."
        case .accessibility:
            "So Apace can insert text into the app you're using."
        }
    }
}

/// The grant state of a ``Permission``.
public enum PermissionStatus: Sendable, Equatable {
    /// The user has granted it — the feature works.
    case granted
    /// The user has explicitly refused it; only System Settings can change this.
    case denied
    /// Not yet asked; Apace can still prompt.
    case notDetermined
}
