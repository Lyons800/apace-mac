import ApaceClients
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

            Section("Dictation shortcut") {
                Picker("Key", selection: $settings.dictationActivation) {
                    ForEach(DictationActivationKey.allCases, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                Picker("Behaviour", selection: $settings.dictationShortcutMode) {
                    ForEach(DictationShortcutMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Picker("Cancel recording", selection: $settings.dictationCancelShortcut) {
                    ForEach(DictationCancelShortcut.allCases, id: \.self) { shortcut in
                        Text(shortcut.displayName).tag(shortcut)
                    }
                }
                Text(shortcutNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Microphone") {
                Picker("Input", selection: $settings.selectedInputDeviceID) {
                    Text("System Default").tag(String?.none)
                    ForEach(settings.inputDevices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
                Button("Refresh Devices") { settings.refreshInputDevices() }
                Text(
                    "If the selected microphone disconnects, Apace falls back to the current system default."
                )
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

    private var shortcutNote: String {
        switch settings.dictationShortcutMode {
        case .pushToTalk:
            "Hold \(settings.dictationActivation.displayName) while speaking, then release to insert. A quick tap cancels."
        case .handsFree:
            "Press \(settings.dictationActivation.displayName) once to start and again to insert. Command mode's double-tap gesture is unavailable in hands-free mode."
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
                        "In hold-to-talk mode, double-tap \(settings.dictationActivation.displayName) and hold the second tap, speak a request, and release. Apace answers in the notch, or — for requests like “say this in Portuguese” — rewrites the text field you're focused on and pastes the result."
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

// MARK: - Dictation Health

struct HealthPane: View {
    @Bindable var permissions: PermissionsModel
    @Bindable var modelStatus: ModelStatus
    @State private var health = DictationHealthSnapshot()
    @State private var testText = ""

    var body: some View {
        Form {
            Section("End-to-end test") {
                TextField("Click here, then use your dictation shortcut", text: $testText)
                    .textFieldStyle(.roundedBorder)
                Text(
                    "This field tests the real global shortcut, microphone, transcription, "
                        + "and text insertion path. No diagnostic audio or transcript is saved here."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                ForEach(Permission.allCases, id: \.self) { permission in
                    HStack {
                        Text(permission.title)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(permissionLabel(permissions.status(permission)))
                                .foregroundStyle(
                                    permissions.status(permission) == .granted ? .green : .orange
                                )
                            if !permissions.isRequired(permission) {
                                Text("Not needed for current model")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Button("Refresh Permissions") { permissions.refresh() }
            }

            Section("Live diagnostics") {
                diagnostic("Shortcut", health.lastHotkey ?? "No event seen yet")
                diagnostic("Microphone", health.microphoneName ?? "No recording yet")
                HStack {
                    Text("Input level")
                    Spacer()
                    ProgressView(value: health.inputLevel)
                        .frame(width: 150)
                }
                diagnostic("Last recording", duration(health.lastRecordingDuration))
                diagnostic("Transcription", duration(health.lastTranscriptionDuration))
                diagnostic("Insertion", health.lastInsertion ?? "Not tested yet")
                diagnostic("Model", modelLabel)
                if let error = health.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { permissions.refresh() }
        .task {
            while !Task.isCancelled {
                health = DictationHealthRecorder.shared.snapshot
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func diagnostic(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func duration(_ value: TimeInterval?) -> String {
        value.map { String(format: "%.2f seconds", $0) } ?? "Not tested yet"
    }

    private func permissionLabel(_ status: PermissionStatus) -> String {
        switch status {
        case .granted: "Granted"
        case .denied: "Open System Settings"
        case .notDetermined: "Not requested"
        }
    }

    private var modelLabel: String {
        switch modelStatus.state {
        case .ready: "Ready"
        case .preparing: "Preparing…"
        case .failed(let message): message
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
