import ApaceClients
import ApaceCore
import AppKit
import AudioCapture
import Automation
import SystemServices
import TextCleanup
import Transcription

extension DictationClients {
    /// The production wiring: every port backed by its live adapter. This is the one
    /// place the app reaches into the infrastructure layer; everything else depends
    /// only on the abstract ports.
    static let live = DictationClients(
        audio: .live,
        transcriber: .selected,
        hotkey: .live,
        inserter: .live,
        processor: .live
    )
}

extension CommandClients {
    /// The production wiring for command mode: shared audio and the selected transcriber,
    /// plus screen capture and the vision client that answers with the user's provider.
    static let live = CommandClients(
        audio: .live,
        transcriber: .selected,
        screen: .live,
        vision: .live(apiKey: { provider in CredentialStore.live.load(provider.keyAccount) }),
        automation: .live(
            screen: .live,
            control: .live,
            apiKey: { CredentialStore.live.load(CleanupProvider.anthropic.keyAccount) }
        ),
        hotkey: .command,
        confirm: confirmControlAction
    )

    /// A modal Run/Cancel gate before any risky control action. Modal on purpose — the
    /// user's explicit approval is the safety boundary for letting the model act.
    private static let confirmControlAction: @Sendable (String) async -> Bool = { summary in
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Run this action?"
            alert.informativeText = summary
            alert.addButton(withTitle: "Run")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            return alert.runModal() == .alertFirstButtonReturn
        }
    }
}

extension TextProcessorClient {
    /// Cleans up the transcript before it's inserted, reading both preferences fresh on
    /// every dictation so changes take effect immediately: optional AI cleanup first
    /// (on-device, falling back to the user's API key) when enabled, then the user's
    /// custom vocabulary, which gets the final say on exact spellings.
    static let live = TextProcessorClient(
        process: { text in
            // The full pass: instant tidy, then optional AI cleanup, then vocabulary.
            var result = FastTidy.apply(text)
            if CleanupPreference.isEnabled {
                result = await cleanup.process(result)
            }
            return VocabularyPreference.vocabulary.apply(to: result)
        },
        quick: { text in
            // The instant pass inserted immediately — deterministic tidy + vocabulary, no
            // model. When AI cleanup is on, the coordinator refines this in the background.
            VocabularyPreference.vocabulary.apply(to: FastTidy.apply(text))
        }
    )

    private static let cleanup = TextProcessorClient.aiCleanup(
        provider: { CleanupPreference.provider },
        apiKey: { provider in CredentialStore.live.load(provider.keyAccount) }
    )
}

extension TranscriberClient {
    /// A transcriber that resolves the user's chosen engine on every call, so changing
    /// the engine in settings takes effect on the next dictation with no restart.
    static let selected = TranscriberClient(
        stream: { make(for: EnginePreference.engine).stream($0) },
        transcribe: { try await make(for: EnginePreference.engine).transcribe($0) }
    )
}
