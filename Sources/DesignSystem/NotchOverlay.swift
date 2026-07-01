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

    public init(state: DictationState) {
        self.state = state
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
                EqualizerBars()
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

/// A small equalizer that conveys "listening". It animates on its own for now; a
/// later change drives the bar heights from the live audio level.
private struct EqualizerBars: View {
    @State private var animating = false

    private let heights: [CGFloat] = [10, 20, 13, 22, 11]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(Theme.signal)
                    .frame(width: 3, height: animating ? height : 6)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever()
                            .delay(Double(index) * 0.09),
                        value: animating
                    )
            }
        }
        .frame(height: 24)
        .onAppear { animating = true }
    }
}

#Preview("Listening") {
    NotchOverlay(state: .listening(partial: "the quick brown fox"))
        .padding(40)
        .background(.gray)
}

#Preview("Transcribing") {
    NotchOverlay(state: .transcribing)
        .padding(40)
        .background(.gray)
}
