import ApaceCore
import SwiftUI

/// The notch content for command mode — a listening pill, a working spinner, then the
/// answer (or an error). White on the notch's black chrome, like the dictation content.
public struct NotchCommandContent: View {
    private let activity: CommandActivity
    private let level: Double

    public init(activity: CommandActivity, level: Double = 0) {
        self.activity = activity
        self.level = level
    }

    public var body: some View {
        content
            .font(.system(size: 14, weight: .medium))
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: activity)
    }

    @ViewBuilder
    private var content: some View {
        switch activity {
        case .idle:
            EmptyView()

        case .listening:
            HStack(spacing: 12) {
                Image(systemName: "mic.fill").foregroundStyle(Theme.signal)
                Text("Listening for a command…").foregroundStyle(.white.opacity(0.85))
            }

        case .thinking:
            HStack(spacing: 12) {
                ProgressView().controlSize(.small).tint(Theme.signal)
                Text("Thinking…").foregroundStyle(.white.opacity(0.85))
            }

        case .answer(let text):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Theme.signal).padding(.top, 1)
                Text(text)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360, alignment: .leading)
                    .lineLimit(6)
            }

        case .failed(let message):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}
