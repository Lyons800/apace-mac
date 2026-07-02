import ApaceCore
import AppKit
import DesignSystem
import DynamicNotchKit
import Features
import SwiftUI

/// Presents the dictation and command overlays in the notch using DynamicNotchKit, which
/// provides the native notch-hugging chrome on notched Macs and a floating pill on
/// external displays. It watches both the dictation state and the command activity and
/// expands the notch while either is in flight, hiding it when both are idle.
@MainActor
final class NotchOverlayController {
    private let dictation: DictationModel
    private let command: CommandModel

    private lazy var notch = DynamicNotch(hoverBehavior: [.keepVisible], style: .auto) {
        [dictation, command] in
        NotchContent(dictation: dictation, command: command)
    }

    init(dictation: DictationModel, command: CommandModel) {
        self.dictation = dictation
        self.command = command
    }

    /// Starts reacting to state changes. The notch expands on the first activity and
    /// hides once everything returns to idle.
    func present() {
        observe()
        react()
    }

    private func observe() {
        withObservationTracking {
            _ = dictation.state
            _ = command.activity
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.react()
                self.observe()
            }
        }
    }

    private func react() {
        let dictating = dictation.state != .idle
        if dictating || command.activity.isActive {
            Task { await notch.expand() }
        } else {
            Task { await notch.hide() }
        }
    }
}

/// The SwiftUI content shown inside the notch. It observes both models, showing the
/// command answer when command mode is active and the dictation transcript otherwise.
/// The notch chrome supplies the black background on notched Macs; on a floating
/// (no-notch) display we paint our own so it matches.
private struct NotchContent: View {
    let dictation: DictationModel
    let command: CommandModel

    private var isFloating: Bool {
        (NSScreen.screens.first?.safeAreaInsets.top ?? 0) <= 0
    }

    var body: some View {
        Group {
            if command.activity.isActive {
                NotchCommandContent(activity: command.activity)
            } else {
                NotchOverlayContent(state: dictation.state, level: dictation.audioLevel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 480, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background { if isFloating { Color.black.padding(-16) } }
    }
}
