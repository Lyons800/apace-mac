import ApaceClients
import ApaceCore
import SwiftUI

/// The settings window, organized like macOS System Settings: a sidebar of sections on
/// the left, a focused pane on the right. Each pane groups related controls so it's
/// obvious where to turn something on or paste a key.
public struct SettingsRootView: View {
    @Bindable private var settings: SettingsStore
    @Bindable private var vocabulary: VocabularyStore
    @Bindable private var permissions: PermissionsModel
    @Bindable private var modelStatus: ModelStatus
    @State private var selection: SettingsSection = .general

    public init(
        settings: SettingsStore,
        vocabulary: VocabularyStore,
        permissions: PermissionsModel,
        modelStatus: ModelStatus
    ) {
        self.settings = settings
        self.vocabulary = vocabulary
        self.permissions = permissions
        self.modelStatus = modelStatus
    }

    public var body: some View {
        NavigationSplitView {
            List(sections, selection: $selection) { section in
                Label(section.title, systemImage: section.icon).tag(section)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 700, height: 540)
    }

    /// Command mode (and its Mac control) is experimental — hidden unless the
    /// experimental flag is set, so a shipped build is core dictation only.
    private var sections: [SettingsSection] {
        SettingsSection.allCases.filter { $0 != .command || ExperimentalPreference.isEnabled }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general: GeneralPane(settings: settings)
        case .transcription: TranscriptionPane(settings: settings)
        case .cleanup: CleanupPane(settings: settings)
        case .command: CommandPane(settings: settings)
        case .dictionary: DictionaryPane(vocabulary: vocabulary)
        case .health:
            HealthPane(permissions: permissions, modelStatus: modelStatus)
        case .about: AboutPane()
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case transcription
    case cleanup
    case command
    case dictionary
    case health
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .transcription: "Transcription"
        case .cleanup: "Cleanup"
        case .command: "Command mode"
        case .dictionary: "Names & Terms"
        case .health: "Dictation Health"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .transcription: "waveform"
        case .cleanup: "sparkles"
        case .command: "command"
        case .dictionary: "person.wave.2"
        case .health: "stethoscope"
        case .about: "info.circle"
        }
    }
}
