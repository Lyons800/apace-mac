import ApaceClients
import ApaceCore
import Foundation
import Observation

/// The observable store behind the settings window. It surfaces the persisted
/// preferences for the UI to bind to, and writes changes straight back — the toggles and
/// pickers through their UserDefaults seams, the API keys through the Keychain-backed
/// credential store — so they take effect on the next dictation or command.
@Observable
public final class SettingsStore {
    /// The overall on-device-vs-cloud stance. Changing it applies that mode's recommended
    /// cleanup and vision providers; individual capabilities can still be overridden.
    public var processingMode: ProcessingMode {
        didSet {
            ProcessingModePreference.mode = processingMode
            cleanupProvider = processingMode.recommendedCleanupProvider
            visionProvider = VisionProvider.recommended(for: processingMode)
        }
    }

    public var engine: TranscriptionEngine {
        didSet {
            EnginePreference.engine = engine
            NotificationCenter.default.post(name: .apaceTranscriptionEngineChanged, object: nil)
        }
    }

    public var transcriptionLanguage: TranscriptionLanguage {
        didSet { SpeechLanguagePreference.language = transcriptionLanguage }
    }

    public var dictationActivation: DictationActivationKey {
        didSet { DictationShortcutPreference.activation = dictationActivation }
    }

    public var dictationShortcutMode: DictationShortcutMode {
        didSet { DictationShortcutPreference.mode = dictationShortcutMode }
    }

    public var dictationCancelShortcut: DictationCancelShortcut {
        didSet { DictationShortcutPreference.cancel = dictationCancelShortcut }
    }

    public private(set) var inputDevices: [AudioInputDevice] = []
    public var selectedInputDeviceID: String? {
        didSet { MicrophonePreference.selectedUID = selectedInputDeviceID }
    }

    public var aiCleanupEnabled: Bool {
        didSet { CleanupPreference.isEnabled = aiCleanupEnabled }
    }

    /// The cleanup provider. Changing it reloads the API key for the newly-selected one.
    public var cleanupProvider: CleanupProvider {
        didSet {
            CleanupPreference.provider = cleanupProvider
            apiKey = loadKey(
                account: cleanupProvider.keyAccount,
                requires: cleanupProvider.requiresAPIKey
            )
        }
    }

    /// The API key for the currently-selected cleanup provider; empty for on-device.
    public var apiKey: String {
        didSet {
            persistKey(
                apiKey,
                account: cleanupProvider.keyAccount,
                requires: cleanupProvider.requiresAPIKey
            )
        }
    }

    public var commandEnabled: Bool {
        didSet { CommandPreference.isEnabled = commandEnabled }
    }

    public var commandVision: Bool {
        didSet { CommandPreference.usesVision = commandVision }
    }

    public var commandControl: Bool {
        didSet { CommandPreference.controlEnabled = commandControl }
    }

    public var commandFollowUps: Bool {
        didSet { CommandPreference.followUpsEnabled = commandFollowUps }
    }

    /// The provider that answers commands. Changing it reloads its API key.
    public var visionProvider: VisionProvider {
        didSet {
            CommandPreference.provider = visionProvider
            visionKey = loadKey(
                account: visionProvider.keyAccount,
                requires: visionProvider.requiresAPIKey
            )
        }
    }

    /// The API key for the currently-selected vision provider; empty for on-device.
    public var visionKey: String {
        didSet {
            persistKey(
                visionKey,
                account: visionProvider.keyAccount,
                requires: visionProvider.requiresAPIKey
            )
        }
    }

    private let credentials: CredentialStore
    private let audioDevices: AudioDeviceClient

    public init(
        credentials: CredentialStore,
        audioDevices: AudioDeviceClient = .unavailable
    ) {
        self.credentials = credentials
        self.audioDevices = audioDevices
        processingMode = ProcessingModePreference.mode
        engine = EnginePreference.engine
        transcriptionLanguage = SpeechLanguagePreference.language
        dictationActivation = DictationShortcutPreference.activation
        dictationShortcutMode = DictationShortcutPreference.mode
        dictationCancelShortcut = DictationShortcutPreference.cancel
        selectedInputDeviceID = MicrophonePreference.selectedUID
        aiCleanupEnabled = CleanupPreference.isEnabled
        cleanupProvider = CleanupPreference.provider
        apiKey = ""
        commandEnabled = CommandPreference.isEnabled
        commandVision = CommandPreference.usesVision
        commandControl = CommandPreference.controlEnabled
        commandFollowUps = CommandPreference.followUpsEnabled
        visionProvider = CommandPreference.provider
        visionKey = ""
        apiKey = loadKey(
            account: cleanupProvider.keyAccount,
            requires: cleanupProvider.requiresAPIKey
        )
        visionKey = loadKey(
            account: visionProvider.keyAccount,
            requires: visionProvider.requiresAPIKey
        )
        refreshInputDevices()
    }

    public func refreshInputDevices() {
        inputDevices = audioDevices.inputDevices()
        if let selectedInputDeviceID,
            !inputDevices.contains(where: { $0.id == selectedInputDeviceID })
        {
            // Keep the preference so reconnecting restores it; capture transparently
            // uses System Default until then.
            inputDevices.insert(
                AudioInputDevice(
                    id: selectedInputDeviceID,
                    name: "Unavailable device — using System Default"
                ),
                at: 0
            )
        }
    }

    private func loadKey(account: String, requires: Bool) -> String {
        guard requires else { return "" }
        return credentials.load(account) ?? ""
    }

    private func persistKey(_ key: String, account: String, requires: Bool) {
        guard requires else { return }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            credentials.delete(account)
        } else {
            credentials.save(trimmed, account)
        }
    }
}
