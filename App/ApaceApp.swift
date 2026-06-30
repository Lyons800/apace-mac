import ApaceCore
import Features
import SwiftUI

@main
struct ApaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(dictation: delegate.dictation)
        } label: {
            Image(systemName: delegate.dictation.state.menuBarSymbol)
        }
    }
}

/// The menu shown from the status item. The notch overlay in milestone M3 becomes the
/// primary surface; this stays as the always-available controls and status.
private struct MenuContent: View {
    let dictation: DictationModel

    var body: some View {
        Text(dictation.state.menuBarTitle)
            .font(.headline)

        Divider()

        Button("Quit Apace") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

extension DictationState {
    /// SF Symbol shown in the status bar for the current state.
    var menuBarSymbol: String {
        switch self {
        case .idle, .failed: "mic"
        case .listening: "mic.fill"
        case .transcribing, .inserting: "waveform"
        }
    }

    /// One-line, human-readable status for the menu header.
    var menuBarTitle: String {
        switch self {
        case .idle: "Ready"
        case .listening: "Listening…"
        case .transcribing: "Transcribing…"
        case .inserting: "Inserting…"
        case .failed(let message): message
        }
    }
}
