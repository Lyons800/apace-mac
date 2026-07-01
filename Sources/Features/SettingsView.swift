import ApaceCore
import SwiftUI

/// The settings window. For now it's the transcription engine picker; more sections
/// (hotkey, dictionary, command mode) land with their milestones.
public struct SettingsView: View {
    @Bindable private var settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section("Transcription") {
                Picker("Engine", selection: $settings.engine) {
                    ForEach(TranscriptionEngine.allCases, id: \.self) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                Text(engineNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 200)
    }

    /// Honest about what's live: Apple works today; the others are on the way, and the
    /// app quietly falls back to Apple until they land.
    private var engineNote: String {
        switch settings.engine {
        case .apple:
            "Built into macOS — instant, private, no download."
        case .whisper, .parakeet:
            "Coming soon. Apace uses Apple's engine until \(settings.engine.displayName) lands."
        }
    }
}
