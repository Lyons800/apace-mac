import ApaceCore
import Observation

/// The observable store backing the dictation surface (the notch overlay).
///
/// It owns the current ``DictationState`` and, once wired in milestone M1, will
/// consume *throttled* updates from the audio/transcription pipeline and expose them
/// to SwiftUI. High-frequency data (audio levels, volatile partials) is sampled down
/// before it reaches here, so the render path stays cheap regardless of pipeline
/// throughput. Runs on the main actor (the module default).
@Observable
public final class DictationModel {
    public private(set) var state: DictationState = .idle

    public init() {}
}
