import ApaceCore
import Testing

@testable import DictationPipeline

@Suite("Dictation controller")
struct DictationControllerTests {
    @Test("A full dictation captures, transcribes, and inserts the final text")
    func fullDictation() async {
        let recorder = Recorder()
        let controller = DictationController(clients: makeClients(recorder: recorder))

        await controller.handle(.startDictation)
        await #expect(controller.currentState == .listening(partial: ""))

        await controller.handle(.stopDictation)
        await #expect(controller.currentState == .idle)
        #expect(recorder.inserted == ["hello world"])
        #expect(recorder.stopCount == 1)
    }

    @Test("Silence is dropped, real speech passes the gate")
    func speechGate() {
        // Silence and near-silent noise-floor buffers are rejected; a speech-level buffer
        // passes.
        #expect(!DictationController.hasSpeech(Array(repeating: 0, count: 8_000)))
        #expect(!DictationController.hasSpeech(Array(repeating: 0.001, count: 8_000)))
        #expect(DictationController.hasSpeech(Array(repeating: 0.3, count: 8_000)))
    }

    @Test("Inserts the quick text immediately, then swaps in the refined version")
    func refinesAfterInserting() async {
        let recorder = Recorder()
        let controller = DictationController(
            clients: makeClients(
                recorder: recorder,
                transcribe: { _ in "raw text" },
                process: { _ in "cleaned text" },
                quick: { _ in "raw text" }
            )
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)

        // The quick transcript is inserted with no wait…
        #expect(recorder.inserted == ["raw text"])
        // …and the cleaned version is swapped in by the background refine.
        let swapped = await waitUntil { recorder.replaced == ["cleaned text"] }
        #expect(swapped)
    }

    @Test("The transcript is run through the processor before it's inserted")
    func processesBeforeInserting() async {
        let recorder = Recorder()
        let controller = DictationController(
            clients: makeClients(recorder: recorder, process: { $0.uppercased() })
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)

        #expect(recorder.inserted == ["HELLO WORLD"])
    }

    @Test("An empty transcript inserts nothing and returns to idle")
    func emptyTranscript() async {
        let recorder = Recorder()
        let controller = DictationController(
            clients: makeClients(recorder: recorder, transcribe: { _ in "" })
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)

        await #expect(controller.currentState == .idle)
        #expect(recorder.inserted.isEmpty)
    }

    @Test("A microphone that won't start surfaces a recoverable failure")
    func microphoneFailure() async {
        let recorder = Recorder()
        let controller = DictationController(
            clients: makeClients(recorder: recorder, startThrows: true)
        )

        await controller.handle(.startDictation)

        await #expect(
            controller.currentState == .failed(message: DictationController.microphoneErrorMessage)
        )
        #expect(recorder.inserted.isEmpty)
    }

    @Test("A transcription error surfaces a recoverable failure")
    func transcriptionFailure() async {
        let recorder = Recorder()
        let controller = DictationController(
            clients: makeClients(
                recorder: recorder,
                transcribe: { _ in throw FakeError.transcriptionFailed }
            )
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)

        await #expect(
            controller.currentState
                == .failed(message: DictationController.transcriptionErrorMessage)
        )
        #expect(recorder.inserted.isEmpty)
    }

    @Test("Cancelling discards the dictation without inserting")
    func cancel() async {
        let recorder = Recorder()
        let controller = DictationController(clients: makeClients(recorder: recorder))

        await controller.handle(.startDictation)
        await controller.handle(.cancel)

        await #expect(controller.currentState == .idle)
        #expect(recorder.inserted.isEmpty)
        #expect(recorder.stopCount == 1)
    }

    @Test("Toggle starts a dictation, then a second toggle finishes it")
    func toggle() async {
        let recorder = Recorder()
        let controller = DictationController(clients: makeClients(recorder: recorder))

        await controller.handle(.toggleDictation)
        await #expect(controller.currentState == .listening(partial: ""))

        await controller.handle(.toggleDictation)
        await #expect(controller.currentState == .idle)
        #expect(recorder.inserted == ["hello world"])
    }

    @Test("The live preview re-transcribes the recent audio while listening")
    func livePreview() async {
        let recorder = Recorder()
        let controller = DictationController(
            clients: makeClients(
                recorder: recorder,
                samples: Array(repeating: 0.1, count: 10_000),
                transcribe: { _ in "live preview" }
            )
        )

        await controller.handle(.startDictation)

        let reachedPreview = await waitUntil {
            await controller.currentState == .listening(partial: "live preview")
        }
        #expect(reachedPreview)
    }

    @Test("run() drives the flow from the hotkey intent stream")
    func runConsumesHotkeyStream() async {
        let recorder = Recorder()
        let (intents, continuation) = AsyncStream.makeStream(of: HotkeyIntent.self)
        let controller = DictationController(
            clients: makeClients(recorder: recorder, hotkey: .init(intents: { intents }))
        )

        let loop = Task { await controller.run() }
        continuation.yield(.startDictation)
        continuation.yield(.stopDictation)
        continuation.finish()
        await loop.value

        #expect(recorder.inserted == ["hello world"])
    }
}
