import AppKit
import Features
import SwiftUI

/// Opens the settings window from the menu bar. A menu-bar app owns no window, so the
/// delegate keeps this controller and shows the window on demand.
@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private let vocabulary: VocabularyStore
    private var window: NSWindow?

    init(settings: SettingsStore, vocabulary: VocabularyStore) {
        self.settings = settings
        self.vocabulary = vocabulary
    }

    func present() {
        if window == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(
                    rootView: SettingsView(settings: settings, vocabulary: vocabulary)
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
