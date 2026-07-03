import ApaceClients
import AppKit
import Features
import SystemServices
import TextCleanup
import Transcription

/// Owns the app's long-lived models and brings them to life once the app has finished
/// launching. Keeping these here (rather than as `@State` on the `App`) gives them a
/// stable lifetime independent of SwiftUI re-evaluating the scene.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let dictation = DictationModel(clients: .live)
    let command = CommandModel(clients: .live)
    let permissions = PermissionsModel(client: .live)
    let settings = SettingsStore(credentials: .live)
    let vocabulary = VocabularyStore()
    let modelStatus = ModelStatus(isReady: !EnginePreference.engine.requiresModelDownload)

    private var overlay: NotchOverlayController?
    private var onboarding: OnboardingWindowController?
    private lazy var settingsWindow = SettingsWindowController(
        settings: settings,
        vocabulary: vocabulary
    )
    private lazy var historyWindow = HistoryWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        dictation.activate()
        command.activate()

        // Warm up the chosen engine's model so the first dictation doesn't wait on a
        // download, and flip the menu's "preparing model" line off once it's ready.
        let engine = EnginePreference.engine
        if engine.requiresModelDownload {
            Task { @MainActor in
                await TranscriberClient.prepare(engine)
                modelStatus.isReady = true
            }
        }

        // Likewise warm up the local cleanup model when on-device cleanup is on and will
        // fall back to it (no Apple Intelligence).
        if CleanupPreference.isEnabled, CleanupPreference.provider == .onDevice {
            TextProcessorClient.preloadOnDeviceCleanup()
        }

        let overlay = NotchOverlayController(dictation: dictation, command: command)
        overlay.present()
        self.overlay = overlay

        let onboarding = OnboardingWindowController(permissions: permissions)
        onboarding.presentIfNeeded()
        self.onboarding = onboarding
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // The user may have just toggled a grant in System Settings; re-check so
        // onboarding notices without them having to reopen it.
        permissions.refresh()
    }

    func openSettings() {
        settingsWindow.present()
    }

    func openHistory() {
        historyWindow.present()
    }
}
