import AppKit
import Features
import SwiftUI

/// Opens the settings window from the menu bar. A menu-bar app owns no window, so the
/// delegate keeps this controller and shows the window on demand.
@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private let vocabulary: VocabularyStore
    private let permissions: PermissionsModel
    private let modelStatus: ModelStatus
    private let command: CommandModel
    private var window: NSWindow?

    init(
        settings: SettingsStore,
        vocabulary: VocabularyStore,
        permissions: PermissionsModel,
        modelStatus: ModelStatus,
        command: CommandModel
    ) {
        self.settings = settings
        self.vocabulary = vocabulary
        self.permissions = permissions
        self.modelStatus = modelStatus
        self.command = command
    }

    func present() {
        permissions.refresh()
        if window == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(
                    rootView: SettingsRootView(
                        settings: settings,
                        vocabulary: vocabulary,
                        permissions: permissions,
                        modelStatus: modelStatus,
                        command: command
                    )
                )
            )
            window.title = "Apace Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
