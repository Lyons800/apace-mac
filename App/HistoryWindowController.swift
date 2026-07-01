import AppKit
import Features
import SwiftUI

/// Opens the history window from the menu bar and refreshes it each time, since new
/// dictations are recorded while the window is closed.
@MainActor
final class HistoryWindowController {
    private let history = HistoryModel()
    private var window: NSWindow?

    func present() {
        history.refresh()

        if window == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(rootView: HistoryView(history: history))
            )
            window.title = "Dictation History"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
