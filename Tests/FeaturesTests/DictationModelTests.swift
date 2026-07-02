import ApaceClients
import ApaceCore
import Testing

@testable import Features

@MainActor
@Suite("Dictation model")
struct DictationModelTests {
    @Test("Republishes the coordinator's state through a full dictation")
    func republishesState() async {
        let model = DictationModel(clients: stubClients(transcript: "all done"))
        model.activate()

        await model.send(.startDictation)
        #expect(await waitUntil { model.state == .listening(partial: "") })

        await model.send(.stopDictation)
        #expect(await waitUntil { model.state == .idle })
    }

    @Test("Starts out idle before anything happens")
    func startsIdle() {
        let model = DictationModel(clients: stubClients(transcript: ""))
        #expect(model.state == .idle)
    }
}

/// A minimal set of fake ports: silent audio and hotkey, a transcriber that returns a
/// fixed string, and a no-op inserter. Enough to drive the model's observation path.
private func stubClients(transcript: String) -> DictationClients {
    DictationClients(
        audio: AudioCaptureClient(
            start: { AsyncStream { $0.finish() } },
            samples: { [] },
            stop: { Array(repeating: 0.1, count: 8_000) }
        ),
        transcriber: TranscriberClient(
            stream: { _ in AsyncThrowingStream { $0.finish() } },
            transcribe: { _ in transcript }
        ),
        hotkey: HotkeyClient(intents: { AsyncStream { $0.finish() } }),
        inserter: TextInserterClient(insert: { _ in })
    )
}

/// Polls `predicate` on the main actor until it holds or a short budget elapses; the
/// model republishes state on a background observation task, so the assertion has to
/// wait for that hop.
@MainActor
private func waitUntil(_ predicate: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if predicate() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return predicate()
}
