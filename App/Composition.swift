import ApaceClients
import AudioCapture
import SystemServices
import TextCleanup
import Transcription

extension DictationClients {
    /// The production wiring: every port backed by its live adapter. This is the one
    /// place the app reaches into the infrastructure layer; everything else depends
    /// only on the abstract ports.
    static let live = DictationClients(
        audio: .live,
        transcriber: .selected,
        hotkey: .live,
        inserter: .live,
        processor: .live
    )
}

extension TextProcessorClient {
    /// Cleans up the transcript before it's inserted, reading both preferences fresh on
    /// every dictation so changes take effect immediately: optional AI cleanup first
    /// (when the user has enabled it), then the user's custom vocabulary, which gets the
    /// final say on exact spellings.
    static let live = TextProcessorClient { text in
        var result = text
        if CleanupPreference.isEnabled {
            result = await appleIntelligence.process(result)
        }
        return VocabularyPreference.vocabulary.apply(to: result)
    }
}

extension TranscriberClient {
    /// A transcriber that resolves the user's chosen engine on every call, so changing
    /// the engine in settings takes effect on the next dictation with no restart.
    static let selected = TranscriberClient(
        stream: { make(for: EnginePreference.engine).stream($0) },
        transcribe: { try await make(for: EnginePreference.engine).transcribe($0) }
    )
}
