import ApaceCore
import SwiftUI

/// The settings window, organized like macOS System Settings: a sidebar of sections on
/// the left, a focused pane on the right. Each pane groups related controls so it's
/// obvious where to turn something on or paste a key.
public struct SettingsRootView: View {
    @Bindable private var settings: SettingsStore
    @Bindable private var vocabulary: VocabularyStore
    @State private var selection: SettingsSection = .transcription

    public init(settings: SettingsStore, vocabulary: VocabularyStore) {
        self.settings = settings
        self.vocabulary = vocabulary
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon).tag(section)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 660, height: 480)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .transcription: TranscriptionPane(settings: settings)
        case .cleanup: CleanupPane(settings: settings)
        case .dictionary: DictionaryPane(vocabulary: vocabulary)
        case .about: AboutPane()
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case transcription
    case cleanup
    case dictionary
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transcription: "Transcription"
        case .cleanup: "Cleanup"
        case .dictionary: "Dictionary"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .transcription: "waveform"
        case .cleanup: "sparkles"
        case .dictionary: "character.book.closed"
        case .about: "info.circle"
        }
    }
}
