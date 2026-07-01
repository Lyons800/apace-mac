import AppKit
import DesignSystem
import Features
import SwiftUI

/// Presents the dictation overlay in a borderless, click-through panel pinned under
/// the notch. The panel stays on screen; the SwiftUI content animates itself in and
/// out as the dictation state changes, so there's no window bookkeeping to get wrong.
@MainActor
final class NotchOverlayController {
    private let panel: NSPanel

    init(model: DictationModel) {
        panel = Self.makePanel(hosting: OverlayHost(model: model))
    }

    /// Puts the panel on screen. Call once after launch.
    func present() {
        reposition()
        panel.orderFrontRegardless()
    }

    private func reposition() {
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        panel.setFrameOrigin(origin)
    }

    private static func makePanel(hosting host: some View) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 84),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let hosting = NSHostingView(rootView: host)
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 84)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        return panel
    }
}

/// The SwiftUI root inside the panel. It observes the model, so reading `state`
/// re-renders the overlay whenever the dictation transitions.
private struct OverlayHost: View {
    let model: DictationModel

    var body: some View {
        NotchOverlay(state: model.state, level: model.audioLevel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 6)
    }
}
