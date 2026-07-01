import AppKit
import Features
import SystemServices

/// Owns the app's long-lived models and brings them to life once the app has finished
/// launching. Keeping these here (rather than as `@State` on the `App`) gives them a
/// stable lifetime independent of SwiftUI re-evaluating the scene.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let dictation = DictationModel(clients: .live)
    let permissions = PermissionsModel(client: .live)
    let settings = SettingsStore()

    private var overlay: NotchOverlayController?
    private var onboarding: OnboardingWindowController?
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        dictation.activate()

        let overlay = NotchOverlayController(model: dictation)
        overlay.present()
        self.overlay = overlay

        let onboarding = OnboardingWindowController(permissions: permissions)
        onboarding.presentIfNeeded()
        self.onboarding = onboarding
    }

    func openSettings() {
        settingsWindow.present()
    }
}
