import AppKit
import Features
import SwiftUI

/// Shows the onboarding flow in a normal window when Apace still needs a permission.
/// A menu-bar app has no window of its own, so the delegate opens this one on first
/// launch and the flow closes it once every grant is in place.
@MainActor
final class OnboardingWindowController {
    private let permissions: PermissionsModel
    private var window: NSWindow?

    init(permissions: PermissionsModel) {
        self.permissions = permissions
    }

    /// Opens onboarding only if something is still missing.
    func presentIfNeeded() {
        permissions.refresh()
        guard !permissions.allGranted else { return }
        present()
    }

    private func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(permissions: permissions) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to Apace"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
