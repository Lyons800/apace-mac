import ApaceCore
import SwiftUI

/// The settings window: the transcription engine and the custom-vocabulary editor.
/// More sections (hotkey, command mode) land with their milestones.
public struct SettingsView: View {
    @Bindable private var settings: SettingsStore
    @Bindable private var vocabulary: VocabularyStore

    public init(settings: SettingsStore, vocabulary: VocabularyStore) {
        self.settings = settings
        self.vocabulary = vocabulary
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

            Section("Custom words") {
                ForEach($vocabulary.entries) { $entry in
                    HStack(spacing: 8) {
                        TextField("Heard", text: $entry.spoken)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        TextField("Written", text: $entry.written)
                        Button {
                            vocabulary.remove(entry)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }

                Button("Add word", action: vocabulary.add)

                Text("Fix names and jargon the recogniser gets wrong. Applied on-device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 440)
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
