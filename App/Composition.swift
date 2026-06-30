import ApaceClients
import AudioCapture
import SystemServices
import Transcription

extension DictationClients {
    /// The production wiring: every port backed by its live adapter. This is the one
    /// place the app reaches into the infrastructure layer; everything else depends
    /// only on the abstract ports.
    static let live = DictationClients(
        audio: .live,
        transcriber: .live,
        hotkey: .live,
        inserter: .live
    )
}
