import ApaceCore
import AppKit
import DesignSystem
import DynamicNotchKit
import Features
import SwiftUI

/// Presents the dictation overlay in the notch using DynamicNotchKit, which provides
/// the native notch-hugging chrome on notched Macs and a floating pill on external
/// displays. It watches the dictation state and expands the notch while a dictation is
/// in flight, hiding it when idle.
@MainActor
final class NotchOverlayController {
    private let model: DictationModel

    private lazy var notch = DynamicNotch(hoverBehavior: [.keepVisible], style: .auto) {
        [model] in
        NotchContent(model: model)
    }

    init(model: DictationModel) {
        self.model = model
    }

    /// Starts reacting to state changes. The notch expands on the first non-idle state
    /// and hides once the dictation returns to idle.
    func present() {
        observe()
        react(to: model.state)
    }

    private func observe() {
        withObservationTracking {
            _ = model.state
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.react(to: self.model.state)
                self.observe()
            }
        }
    }

    private func react(to state: DictationState) {
        switch state {
        case .idle:
            Task { await notch.hide() }
        case .listening, .transcribing, .inserting, .failed:
            Task { await notch.expand() }
        }
    }
}

/// The SwiftUI content shown inside the notch. It observes the model, so the transcript
/// and level update live; the notch chrome supplies the black background on notched
/// Macs, and on a floating (no-notch) display we paint our own so it matches.
private struct NotchContent: View {
    let model: DictationModel

    private var isFloating: Bool {
        (NSScreen.screens.first?.safeAreaInsets.top ?? 0) <= 0
    }

    var body: some View {
        NotchOverlayContent(state: model.state, level: model.audioLevel)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: 480, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background { if isFloating { Color.black.padding(-16) } }
    }
}
