import ApaceCore
import SwiftUI

/// The dictation overlay that drops down from the notch.
///
/// It renders purely from a ``DictationState`` — the app feeds it the live state and
/// positions it under the notch — so it stays a plain, previewable view with no
/// knowledge of the audio pipeline. When idle it renders nothing, letting the hosting
/// panel disappear.
public struct NotchOverlay: View {
    private let state: DictationState
    private let level: Double

    public init(state: DictationState, level: Double = 0) {
        self.state = state
        self.level = level
    }

    public var body: some View {
        content
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: state)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            EmptyView()

        case .listening(let partial):
            pill {
                EqualizerBars(level: level)
                if !partial.isEmpty {
                    transcript(partial)
                }
            }

        case .transcribing:
            pill {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                label("Transcribing…")
            }

        case .inserting(let text):
            pill {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.signal)
                transcript(text)
            }

        case .failed(let message):
            pill {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                label(message)
            }
        }
    }

    private func transcript(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.head)
            .foregroundStyle(.white)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.white.opacity(0.85))
    }

    private func pill(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: Theme.Spacing.regular) {
            content()
        }
        .font(.callout)
        .padding(.horizontal, Theme.Spacing.loose)
        .padding(.vertical, Theme.Spacing.tight)
        .frame(minHeight: 34)
        .frame(maxWidth: 460)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        )
        .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
    }
}

/// A small equalizer driven by the live microphone level. Each bar has its own weight
/// so louder speech pushes the middle bars highest, giving the classic voice shape.
private struct EqualizerBars: View {
    let level: Double

    private let weights: [CGFloat] = [0.55, 0.85, 1.0, 0.8, 0.6]
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 24

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(weights.enumerated()), id: \.offset) { _, weight in
                Capsule()
                    .fill(Theme.signal)
                    .frame(width: 3, height: height(for: weight))
            }
        }
        .frame(height: maxHeight)
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private func height(for weight: CGFloat) -> CGFloat {
        minHeight + (maxHeight - minHeight) * CGFloat(level) * weight
    }
}

#Preview("Listening") {
    NotchOverlay(state: .listening(partial: "the quick brown fox"), level: 0.7)
        .padding(40)
        .background(.gray)
}

#Preview("Transcribing") {
    NotchOverlay(state: .transcribing)
        .padding(40)
        .background(.gray)
}
