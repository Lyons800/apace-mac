import ApaceCore
import Foundation
import SwiftUI

// MARK: - General

struct GeneralPane: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Mode") {
                Picker("Processing", selection: $settings.processingMode) {
                    ForEach(ProcessingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(modeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var modeNote: String {
        switch settings.processingMode {
        case .onDevice:
            "Everything runs on your Mac — private and offline. Transcription uses "
                + "Parakeet and cleanup uses Apple Intelligence, both on-device. Pick a "
                + "specific model in each section."
        case .cloud:
            "Cleanup (and, later, screen vision) use a cloud provider you choose with "
                + "your own key. Transcription stays on-device — Parakeet is faster than "
                + "and as accurate as the cloud options, so there's nothing to gain."
        }
    }
}

// MARK: - Transcription

struct TranscriptionPane: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Engine") {
                Picker("Model", selection: $settings.engine) {
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
    }

    private var engineNote: String {
        switch settings.engine {
        case .apple:
            "Built into macOS — instant, no download, but can reset on long pauses."
        case .parakeet:
            "On-device, fast and accurate across 25 languages; handles pauses. "
                + "Downloads a model on first use."
        case .parakeetEnglish:
            "On-device, highest English accuracy. Downloads a model on first use."
        case .whisper:
            "On-device, broad language support at good speed. Downloads a ~630 MB model."
        case .whisperMax:
            "On-device, maximum accuracy but slower. Downloads a ~950 MB model."
        }
    }
}

// MARK: - Cleanup

struct CleanupPane: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("AI cleanup") {
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
        }
        .formStyle(.grouped)
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

// MARK: - Dictionary

struct DictionaryPane: View {
    @Bindable var vocabulary: VocabularyStore

    var body: some View {
        Form {
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
    }
}

// MARK: - About

struct AboutPane: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Apace")
                .font(.largeTitle.bold())
            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)
            Text("Fast, private, on-device dictation for macOS.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if let site = URL(string: "https://apace-olyons-projects.vercel.app") {
                    Link("Website", destination: site)
                }
                if let repo = URL(string: "https://github.com/Lyons800/apace-mac") {
                    Link("Source", destination: repo)
                }
            }
            .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
