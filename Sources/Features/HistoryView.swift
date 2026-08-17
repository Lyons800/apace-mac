import ApaceCore
import AppKit
import SwiftUI

/// The history window: a list of recent dictations, each copyable, with a control to
/// clear them. Everything shown here is stored only on the user's Mac.
public struct HistoryView: View {
    private let history: HistoryModel
    @State private var searchText = ""
    @State private var confirmsClear = false

    public init(history: HistoryModel) {
        self.history = history
    }

    public var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "text.quote",
                    description: Text("Text you dictate will appear here.")
                )
            } else {
                List(filteredEntries) { entry in
                    row(for: entry)
                }
            }
        }
        .frame(width: 460, height: 420)
        .toolbar {
            Button("Clear…", role: .destructive) { confirmsClear = true }
                .disabled(history.entries.isEmpty)
        }
        .searchable(text: $searchText, prompt: "Search dictations")
        .confirmationDialog(
            "Clear all dictation history?",
            isPresented: $confirmsClear,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive, action: history.clear)
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear(perform: history.refresh)
    }

    private var filteredEntries: [HistoryEntry] {
        guard !searchText.isEmpty else { return history.entries }
        return history.entries.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func row(for entry: HistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .lineLimit(4)
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                copy(entry)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy transcript")
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Copy") {
                copy(entry)
            }
        }
    }

    private func copy(_ entry: HistoryEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }
}
