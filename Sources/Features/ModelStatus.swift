import Observation

public enum ModelPreparationState: Sendable, Equatable {
    case preparing
    case ready
    case failed(message: String)
}

/// Tracks whether the transcription model is downloaded and loaded, so the menu can show
/// a "preparing model" line on first launch instead of leaving the user wondering why the
/// first dictation is slow.
@Observable
public final class ModelStatus {
    public var state: ModelPreparationState

    public init(isReady: Bool) {
        state = isReady ? .ready : .preparing
    }

    public var isReady: Bool { state == .ready }
}
