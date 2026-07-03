import ApaceCore
import Features
import SwiftUI

@main
struct ApaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(
                dictation: delegate.dictation,
                modelStatus: delegate.modelStatus,
                openSettings: delegate.openSettings,
                openHistory: delegate.openHistory
            )
        } label: {
            Image(systemName: delegate.dictation.state.menuBarSymbol)
        }
    }
}

/// The menu shown from the status item. The notch overlay is the primary surface; this
/// stays as the always-available controls and status.
private struct MenuContent: View {
    let dictation: DictationModel
    let modelStatus: ModelStatus
    let openSettings: () -> Void
    let openHistory: () -> Void

    var body: some View {
        Text(dictation.state.menuBarTitle)
            .font(.headline)

        if !modelStatus.isReady {
            Text("Preparing dictation model… (first launch)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Divider()

        Button("History…", action: openHistory)
        Button("Settings…", action: openSettings)
            .keyboardShortcut(",")

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
