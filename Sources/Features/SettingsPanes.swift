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
            "Cleanup and command-mode screen vision use a cloud provider you choose with "
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
                Picker("Language", selection: $settings.transcriptionLanguage) {
                    ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
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
            "On-device, highest English accuracy. This model always uses English. "
                + "Downloads a model on first use."
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
            "Runs entirely on your Mac — Apple Intelligence where available, otherwise a "
                + "small local model (downloaded once)."
        default:
            "Your transcript is sent to \(settings.cleanupProvider.displayName) only when "
                + "cleanup runs. The key is stored in your Keychain."
        }
    }
}

// MARK: - Command mode

struct CommandPane: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Command mode") {
                Toggle("Enable command mode", isOn: $settings.commandEnabled)

                if settings.commandEnabled {
                    Text(
                        "Double-tap Right Option and hold the second tap, speak a request, and release. Apace answers in the notch, or — for requests like “say this in Portuguese” — rewrites the text field you're focused on and pastes the result. (A single hold dictates as usual.)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Toggle("Let it see my screen", isOn: $settings.commandVision)

                    Picker("Provider", selection: $settings.visionProvider) {
                        ForEach(VisionProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    if settings.visionProvider.requiresAPIKey {
                        SecureField("API key", text: $settings.visionKey)
                    }

                    Text(providerNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Toggle("Let it control my Mac (experimental)", isOn: $settings.commandControl)
                    if settings.commandControl {
                        Text(
                            "A command drives your mouse and keyboard to carry out the task, via Claude's computer-use. It asks before anything is sent, deleted, or bought. Needs an Anthropic key (set in Cleanup) plus Screen Recording and Accessibility permission."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var providerNote: String {
        switch settings.visionProvider {
        case .onDevice:
            "Answers on your Mac with Apple Intelligence (macOS 26). On-device screen "
                + "vision is limited today — use a cloud provider for full screen understanding."
        case .anthropic:
            "Sends your request — and the screenshot, if enabled — to Anthropic's Claude. "
                + "Uses the same key as Cleanup and Mac control, stored in your Keychain."
        case .gemini:
            "Sends your request — and the screenshot, if enabled — to Google Gemini. The "
                + "key is stored in your Keychain."
        }
    }
}

// MARK: - Names & Terms

struct DictionaryPane: View {
    @Bindable var vocabulary: VocabularyStore

    var body: some View {
        Form {
            Section("Teach Apace") {
                ForEach($vocabulary.entries) { $entry in
                    HStack(alignment: .center, spacing: 8) {
                        TextField("Name or term", text: $entry.term)
                        TextField("What Apace hears (optional)", text: $entry.pronunciation)
                        learningButton(for: entry)
                        Button {
                            vocabulary.remove(entry)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }

                Button("Add name or term", action: vocabulary.add)

                Text(
                    "Apace gives these spellings to the recogniser before it listens. "
                        + "For a name like Oisin, click the microphone, say only the name, "
                        + "then click Stop. Apace learns the recogniser’s pronunciation without "
                        + "creating a global find-and-replace rule."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let message = vocabulary.learningMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func learningButton(for entry: VocabularyEntry) -> some View {
        if vocabulary.processingEntryID == entry.id {
            ProgressView()
                .controlSize(.small)
                .frame(width: 24)
        } else {
            let isRecording = vocabulary.recordingEntryID == entry.id
            Button {
                vocabulary.toggleLearning(entry)
            } label: {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isRecording ? .red : .secondary)
            .disabled(
                entry.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || vocabulary.processingEntryID != nil
            )
            .help(isRecording ? "Stop and learn" : "Learn pronunciation")
        }
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
