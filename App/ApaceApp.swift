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
                retryModelPreparation: delegate.prepareSelectedModel,
                canCheckForUpdates: delegate.canCheckForUpdates,
                checkForUpdates: delegate.checkForUpdates,
                openSettings: delegate.openSettings,
                openHistory: delegate.openHistory
            )
        } label: {
            // Keep a stable, brand-like waveform in the menu bar. A generic mic that
            // flips between outline and filled states is easily mistaken for a second
            // microphone control or macOS's own recording indicators.
            Image(systemName: "waveform")
                .accessibilityLabel("Apace")
        }
    }
}

/// The menu shown from the status item. The notch overlay is the primary surface; this
/// stays as the always-available controls and status.
private struct MenuContent: View {
    let dictation: DictationModel
    let modelStatus: ModelStatus
    let retryModelPreparation: () -> Void
    let canCheckForUpdates: Bool
    let checkForUpdates: () -> Void
    let openSettings: () -> Void
    let openHistory: () -> Void

    var body: some View {
        Text(dictation.state.menuBarTitle)
            .font(.headline)

        switch modelStatus.state {
        case .preparing:
            Text("Preparing dictation model… (first launch)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            Button("Retry Model Download", action: retryModelPreparation)
        case .ready:
            EmptyView()
        }

        Divider()

        Button("History…", action: openHistory)
        Button("Settings…", action: openSettings)
            .keyboardShortcut(",")

        if canCheckForUpdates {
            Button("Check for Updates…", action: checkForUpdates)
        }

        Button("Quit Apace") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

extension DictationState {
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
