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
        .safeAreaInset(edge: .bottom) {
            if let message = history.recoveryMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
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
                Text(entry.text.isEmpty ? statusTitle(for: entry) : entry.text)
                    .lineLimit(4)
                HStack(spacing: 6) {
                    statusLabel(for: entry)
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let error = entry.errorMessage, entry.status != .inserted {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if entry.status.isRecoverable {
                Button {
                    history.retry(entry)
                } label: {
                    if history.retryingID == entry.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(history.retryingID != nil)
                .help("Retry dictation")
            }
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
            if entry.status.isRecoverable {
                Button("Retry", action: { history.retry(entry) })
            }
            Button("Copy") {
                copy(entry)
            }
            .disabled(entry.text.isEmpty)
        }
    }

    private func statusTitle(for entry: HistoryEntry) -> String {
        entry.hasAudio ? "Recoverable dictation" : "Dictation failed"
    }

    @ViewBuilder
    private func statusLabel(for entry: HistoryEntry) -> some View {
        switch entry.status {
        case .processing:
            Label(
                "Interrupted",
                systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
            )
        case .inserted: Label("Inserted", systemImage: "checkmark.circle")
        case .copiedToClipboard: Label("Copied", systemImage: "doc.on.clipboard")
        case .failed: Label("Failed", systemImage: "exclamationmark.triangle")
        }
    }

    private func copy(_ entry: HistoryEntry) {
        guard !entry.text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }
}
