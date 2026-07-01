import ApaceCore
import AppKit
import SwiftUI

/// The history window: a list of recent dictations, each copyable, with a control to
/// clear them. Everything shown here is stored only on the user's Mac.
public struct HistoryView: View {
    private let history: HistoryModel

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
                List(history.entries) { entry in
                    row(for: entry)
                }
            }
        }
        .frame(width: 460, height: 420)
        .toolbar {
            Button("Clear", role: .destructive, action: history.clear)
                .disabled(history.entries.isEmpty)
        }
        .onAppear(perform: history.refresh)
    }

    private func row(for entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.text)
                .lineLimit(4)
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.text, forType: .string)
            }
        }
    }
}
