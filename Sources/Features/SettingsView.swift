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

            Section("Cleanup") {
                Toggle("Clean up dictation with AI", isOn: $settings.aiCleanupEnabled)

                if settings.aiCleanupEnabled {
                    Picker("Provider", selection: $settings.cleanupProvider) {
                        ForEach(CleanupProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    if settings.cleanupProvider.requiresAPIKey {
                        SecureField("API key", text: $settings.apiKey)
                    }

                    Text(cleanupNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private var engineNote: String {
        switch settings.engine {
        case .apple:
            "Built into macOS — instant, no download, but can reset on long pauses."
        case .parakeet:
            "On-device, fast and accurate; handles pauses. Downloads a model on first use."
        case .whisper:
            "On-device, broad language support. Downloads a model on first use."
        }
    }

    private var cleanupNote: String {
        switch settings.cleanupProvider {
        case .onDevice:
            "Runs on your Mac via Apple Intelligence (macOS 26). A local model for older "
                + "Macs is coming."
        default:
            "Your transcript is sent to \(settings.cleanupProvider.displayName) only when "
                + "cleanup runs. The key is stored in your Keychain."
        }
    }
}
