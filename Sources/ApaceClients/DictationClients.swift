/// The full set of ports the dictation loop drives, bundled so the coordinator takes
/// a single dependency and the composition root wires everything in one place.
///
/// In the app this is built once from the `.live` adapters; in tests it is built from
/// fakes, which is what lets the whole flow run on synthetic audio and hotkeys.
public struct DictationClients: Sendable {
    public var audio: AudioCaptureClient
    public var transcriber: TranscriberClient
    public var hotkey: HotkeyClient
    public var inserter: TextInserterClient
    public var processor: TextProcessorClient

    public init(
        audio: AudioCaptureClient,
        transcriber: TranscriberClient,
        hotkey: HotkeyClient,
        inserter: TextInserterClient,
        processor: TextProcessorClient = .passthrough
    ) {
        self.audio = audio
        self.transcriber = transcriber
        self.hotkey = hotkey
        self.inserter = inserter
        self.processor = processor
    }
}
