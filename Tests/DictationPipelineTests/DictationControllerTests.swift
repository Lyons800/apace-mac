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

    @Test("Streaming partials drive the live listening preview")
    func streamingPartials() async {
        let recorder = Recorder()
        let controller = DictationController(
            clients: makeClients(recorder: recorder, partials: ["hel", "hello"])
        )

        await controller.handle(.startDictation)

        let reachedPreview = await waitUntil {
            await controller.currentState == .listening(partial: "hello")
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
