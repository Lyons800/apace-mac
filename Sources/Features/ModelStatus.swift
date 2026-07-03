import Observation

/// Tracks whether the transcription model is downloaded and loaded, so the menu can show
/// a "preparing model" line on first launch instead of leaving the user wondering why the
/// first dictation is slow.
@Observable
public final class ModelStatus {
    public var isReady: Bool

    public init(isReady: Bool) {
        self.isReady = isReady
    }
}
