import ApaceClients
import ApaceCore
import Foundation
import Testing

@testable import DictationPipeline

/// Thread-safe scratchpad for the command fakes, mirroring `Recorder`.
final class CommandRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _questions: [String] = []
    private var _images: [Data?] = []
    private var _transcribeCalls = 0
    private var _automationCancelled = false
    private var _automationGoals: [String] = []

    var questions: [String] { lock.withLock { _questions } }
    var images: [Data?] { lock.withLock { _images } }
    var transcribeCalls: Int { lock.withLock { _transcribeCalls } }
    var automationCancelled: Bool { lock.withLock { _automationCancelled } }
    var automationGoals: [String] { lock.withLock { _automationGoals } }

    func ask(_ question: String, image: Data?) {
        lock.withLock {
            _questions.append(question)
            _images.append(image)
        }
    }
    func recordTranscribe() { lock.withLock { _transcribeCalls += 1 } }
    func recordAutomationCancelled() { lock.withLock { _automationCancelled = true } }
    func recordAutomation(goal: String) { lock.withLock { _automationGoals.append(goal) } }
}

/// Speech-level samples long enough to clear the command controller's speech gate.
let speechSamples = Array(repeating: Float(0.3), count: 8_000)

func makeCommandClients(
    recorder: CommandRecorder,
    samples: [Float] = speechSamples,
    transcribe: @escaping @Sendable ([Float]) async throws -> String = { _ in "open my calendar" },
    answer: @escaping @Sendable (String, Data?) async throws -> String = { q, _ in "answer to \(q)" },
    screenshot: Data? = Data([0x1]),
    automation: AutomationClient = AutomationClient { _, handler in
        handler.onStep(.done("did it"))
    }
) -> CommandClients {
    CommandClients(
        audio: AudioCaptureClient(
            start: { AsyncStream { $0.finish() } },
            samples: { samples },
            stop: { samples }
        ),
        transcriber: TranscriberClient(
            stream: { _ in AsyncThrowingStream { $0.finish() } },
            transcribe: { s in
                recorder.recordTranscribe()
                return try await transcribe(s)
            }
        ),
        screen: ScreenCaptureClient(capture: { screenshot }),
        vision: VisionClient(respond: { question, image in
            recorder.ask(question, image: image)
            return try await answer(question, image)
        }),
        automation: automation,
        hotkey: HotkeyClient(intents: { AsyncStream { $0.finish() } }),
        confirm: { _ in true }
    )
}

func makePreferences(
    enabled: Bool = true,
    control: Bool = false,
    vision: Bool = true,
    provider: VisionProvider = .gemini
) -> CommandPreferencesReader {
    CommandPreferencesReader(
        isEnabled: { enabled },
        controlEnabled: { control },
        usesVision: { vision },
        provider: { provider }
    )
}

@Suite("Command controller")
struct CommandControllerTests {
    @Test("A full command transcribes and answers with the screenshot")
    func fullCommand() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(recorder: recorder),
            preferences: makePreferences()
        )

        await controller.handle(.startDictation)
        await #expect(controller.currentActivity == .listening(partial: ""))

        await controller.handle(.stopDictation)
        await #expect(controller.currentActivity == .answer("answer to open my calendar"))
        #expect(recorder.questions == ["open my calendar"])
        #expect(recorder.images == [Data([0x1])])
    }

    @Test("A provider without image support gets no screenshot")
    func textOnlyProviderSkipsCapture() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(recorder: recorder),
            preferences: makePreferences(provider: .onDevice)
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        #expect(recorder.images == [nil])
    }

    @Test("A transcription failure reads differently from silence")
    func transcriptionFailure() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                transcribe: { _ in throw FakeError.transcriptionFailed }
            ),
            preferences: makePreferences()
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        await #expect(controller.currentActivity == .failed("Transcription failed — try again."))
    }

    @Test("An empty transcript is reported as not caught")
    func emptyTranscript() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(recorder: recorder, transcribe: { _ in "  " }),
            preferences: makePreferences()
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        await #expect(controller.currentActivity == .failed("I didn't catch that."))
    }

    @Test("Silent audio is dropped without a transcription attempt")
    func silenceGate() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                samples: Array(repeating: 0.0005, count: 8_000)
            ),
            preferences: makePreferences()
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        await #expect(controller.currentActivity == .failed("I didn't catch that."))
        #expect(recorder.transcribeCalls == 0)
    }

    @Test("A new command can start right after an answer, without waiting for the reset")
    func consecutiveCommands() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(recorder: recorder),
            preferences: makePreferences()
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        await #expect(controller.currentActivity == .answer("answer to open my calendar"))

        // The notch still shows the previous answer; a new gesture must not be ignored.
        await controller.handle(.startDictation)
        await #expect(controller.currentActivity == .listening(partial: ""))
    }

    @Test("A new gesture aborts a running control loop")
    func abortsRunningControl() async {
        let recorder = CommandRecorder()
        let hangingAutomation = AutomationClient { goal, _ in
            recorder.recordAutomation(goal: goal)
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                recorder.recordAutomationCancelled()
            }
        }
        let controller = CommandController(
            clients: makeCommandClients(recorder: recorder, automation: hangingAutomation),
            preferences: makePreferences(control: true)
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        let started = await waitUntil { recorder.automationGoals == ["open my calendar"] }
        #expect(started)

        // Double-tapping again while the agent drives the Mac must stop it and listen.
        await controller.handle(.startDictation)
        let cancelled = await waitUntil { recorder.automationCancelled }
        #expect(cancelled)
        await #expect(controller.currentActivity == .listening(partial: ""))
    }
}
