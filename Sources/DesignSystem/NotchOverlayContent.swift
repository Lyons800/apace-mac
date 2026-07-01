import ApaceCore
import SwiftUI

/// The dictation content shown inside the notch — equalizer plus live transcript while
/// listening, a spinner while transcribing, a confirmation as text is inserted. Unlike
/// ``NotchOverlay`` it draws no background: the notch chrome (or the app's floating
/// fallback) supplies that, so this renders in white on top.
public struct NotchOverlayContent: View {
    private let state: DictationState
    private let level: Double

    public init(state: DictationState, level: Double = 0) {
        self.state = state
        self.level = level
    }

    public var body: some View {
        content
            .font(.system(size: 14, weight: .medium))
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: state)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            EmptyView()

        case .listening(let partial):
            HStack(spacing: 12) {
                NotchBars(level: level)
                Text(partial.isEmpty ? "Listening…" : windowed(partial))
                    .foregroundStyle(.white.opacity(partial.isEmpty ? 0.6 : 0.95))
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: 320, alignment: .leading)
            }

        case .transcribing:
            HStack(spacing: 12) {
                ProgressView().controlSize(.small).tint(.white)
                Text("Transcribing…").foregroundStyle(.white.opacity(0.85))
            }

        case .inserting(let text):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.signal)
                Text(text).foregroundStyle(.white.opacity(0.95)).lineLimit(2).truncationMode(.head)
            }

        case .failed(let message):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    /// Keeps the newest words visible on a long utterance without the box growing.
    private func windowed(_ text: String) -> String {
        let maxCharacters = 180
        guard text.count > maxCharacters else { return text }
        let tail = text.suffix(maxCharacters)
        if let space = tail.firstIndex(of: " ") {
            return "…" + tail[tail.index(after: space)...]
        }
        return "…" + tail
    }
}

/// The equalizer for the notch, driven by the live microphone level.
private struct NotchBars: View {
    let level: Double

    private let weights: [CGFloat] = [0.55, 0.85, 1.0, 0.8, 0.6]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(weights.enumerated()), id: \.offset) { _, weight in
                Capsule()
                    .fill(Theme.signal)
                    .frame(width: 3, height: 5 + CGFloat(level) * 18 * weight)
            }
        }
        .frame(height: 22)
        .animation(.easeOut(duration: 0.12), value: level)
    }
}
