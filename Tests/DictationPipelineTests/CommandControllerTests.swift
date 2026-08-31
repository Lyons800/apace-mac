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
    private var _visionQuestions: [String] = []
    private var _transcribeCalls = 0
    private var _automationCancelled = false
    private var _automationGoals: [String] = []
    private var _inserted: [String] = []
    private var _controlActions: [ControlAction] = []
    private var _routedFields: [FocusedField?] = []
    private var _routedConversations: [[CommandTurn]] = []
    private var _automationRequests: [AutomationRequest] = []
    private var _confirmations: [String] = []

    var questions: [String] { lock.withLock { _questions } }
    var images: [Data?] { lock.withLock { _images } }
    var visionQuestions: [String] { lock.withLock { _visionQuestions } }
    var transcribeCalls: Int { lock.withLock { _transcribeCalls } }
    var automationCancelled: Bool { lock.withLock { _automationCancelled } }
    var automationGoals: [String] { lock.withLock { _automationGoals } }
    var inserted: [String] { lock.withLock { _inserted } }
    var controlActions: [ControlAction] { lock.withLock { _controlActions } }
    var routedFields: [FocusedField?] { lock.withLock { _routedFields } }
    var routedConversations: [[CommandTurn]] { lock.withLock { _routedConversations } }
    var automationRequests: [AutomationRequest] { lock.withLock { _automationRequests } }
    var confirmations: [String] { lock.withLock { _confirmations } }

    func ask(_ question: String, image: Data?) {
        lock.withLock {
            _questions.append(question)
            _images.append(image)
        }
    }
    func recordVision(_ question: String) { lock.withLock { _visionQuestions.append(question) } }
    func recordTranscribe() { lock.withLock { _transcribeCalls += 1 } }
    func recordAutomationCancelled() { lock.withLock { _automationCancelled = true } }
    func recordAutomation(goal: String) { lock.withLock { _automationGoals.append(goal) } }
    func recordInsert(_ text: String) { lock.withLock { _inserted.append(text) } }
    func recordControl(_ action: ControlAction) { lock.withLock { _controlActions.append(action) } }
    func recordRoutedField(_ field: FocusedField?) { lock.withLock { _routedFields.append(field) } }
    func recordConversation(_ turns: [CommandTurn]) {
        lock.withLock { _routedConversations.append(turns) }
    }
    func recordAutomation(_ request: AutomationRequest) {
        lock.withLock {
            _automationRequests.append(request)
            _automationGoals.append(request.goal)
        }
    }
    func recordConfirmation(_ summary: String) { lock.withLock { _confirmations.append(summary) } }
}

/// Speech-level samples long enough to clear the command controller's speech gate.
let speechSamples = Array(repeating: Float(0.3), count: 8_000)

func makeCommandClients(
    recorder: CommandRecorder,
    samples: [Float] = speechSamples,
    transcribe: @escaping @Sendable ([Float]) async throws -> String = { _ in "open my calendar" },
    answer: @escaping @Sendable (String, Data?) async throws -> String = { q, _ in "answer to \(q)"
    },
    route:
        @escaping @Sendable (String, FocusedField?, Data?, [CommandTurn]) async throws ->
        CommandDecision = {
            q,
            _,
            _,
            _ in .answer("answer to \(q)")
        },
    field: FocusedField? = nil,
    screenshot: Data? = Data([0x1]),
    automation: AutomationClient = AutomationClient { _, handler in
        handler.onStep(.done("did it"))
    },
    confirm: @escaping @Sendable (String) async -> Bool = { _ in true }
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
            recorder.recordVision(question)
            return try await answer(question, image)
        }),
        router: CommandRouterClient(route: { request, field, image, conversation in
            recorder.ask(request, image: image)
            recorder.recordRoutedField(field)
            recorder.recordConversation(conversation)
            return try await route(request, field, image, conversation)
        }),
        focus: FocusClient(focusedField: { field }),
        inserter: TextInserterClient(
            insert: {
                recorder.recordInsert($0)
                return .inserted
            },
            replaceLast: { _, _ in .inserted }
        ),
        control: ComputerControlClient(perform: { recorder.recordControl($0) }),
        automation: automation,
        hotkey: HotkeyClient(intents: { AsyncStream { $0.finish() } }),
        confirm: {
            recorder.recordConfirmation($0)
            return await confirm($0)
        }
    )
}

func makePreferences(
    enabled: Bool = true,
    control: Bool = false,
    followUps: Bool = true,
    vision: Bool = true,
    provider: VisionProvider = .gemini
) -> CommandPreferencesReader {
    CommandPreferencesReader(
        isEnabled: { enabled },
        controlEnabled: { control },
        followUpsEnabled: { followUps },
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
        let hangingAutomation = AutomationClient { request, _ in
            recorder.recordAutomation(request)
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                recorder.recordAutomationCancelled()
            }
        }
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                route: { request, _, _, _ in
                    .control(goal: request, risk: .readOnly)
                },
                automation: hangingAutomation
            ),
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

    @Test("An insert decision pastes into the focused field without driving the Mac")
    func insertDecision() async {
        let recorder = CommandRecorder()
        let field = FocusedField(appName: "WhatsApp", text: "see you at eight")
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                route: { _, field, _, _ in
                    .insert(text: "até às oito — \(field?.appName ?? "?")", replacesDraft: false)
                },
                field: field,
                automation: AutomationClient { request, _ in recorder.recordAutomation(request) }
            ),
            preferences: makePreferences(control: true)
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        #expect(recorder.inserted == ["até às oito — WhatsApp"])
        #expect(recorder.automationGoals.isEmpty)
        #expect(recorder.controlActions.isEmpty)
        await #expect(controller.currentActivity == .answer("até às oito — WhatsApp"))
    }

    @Test("A replacing insert selects the draft with ⌘A before pasting")
    func replacingInsert() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                route: { _, _, _, _ in .insert(text: "até já", replacesDraft: true) }
            ),
            preferences: makePreferences()
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        #expect(recorder.inserted == ["até já"])
        guard case .key(let code, let flags)? = recorder.controlActions.first else {
            Issue.record("expected a ⌘A before the paste")
            return
        }
        #expect(code == 0)
        #expect(flags == .maskCommand)
    }

    @Test("A control decision with the toggle off explains instead of acting")
    func controlDisabled() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                route: { request, _, _, _ in
                    .control(goal: request, risk: .readOnly)
                },
                automation: AutomationClient { request, _ in recorder.recordAutomation(request) }
            ),
            preferences: makePreferences(control: false)
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        #expect(recorder.automationGoals.isEmpty)
        await #expect(
            controller.currentActivity
                == .answer(
                    "Turn on “Let it control my Mac” (Settings → Commands & Actions) for that."
                )
        )
    }

    @Test("A router failure falls back to the plain answer path")
    func routerFallback() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                route: { _, _, _, _ in throw FakeError.transcriptionFailed }
            ),
            preferences: makePreferences()
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        #expect(recorder.visionQuestions == ["open my calendar"])
        await #expect(controller.currentActivity == .answer("answer to open my calendar"))
    }

    @Test("The router receives the focused field alongside the screenshot")
    func routerContext() async {
        let recorder = CommandRecorder()
        let field = FocusedField(appName: "Mail", selectedText: "hi", text: "hi there")
        let controller = CommandController(
            clients: makeCommandClients(recorder: recorder, field: field),
            preferences: makePreferences()
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        #expect(recorder.routedFields == [field])
        #expect(recorder.images == [Data([0x1])])
    }

    @Test("A second command receives the preceding conversation")
    func followUpContext() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(recorder: recorder),
            preferences: makePreferences(followUps: true)
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)

        #expect(recorder.routedConversations.count == 2)
        #expect(recorder.routedConversations[0].isEmpty)
        #expect(recorder.routedConversations[1].map(\.role) == [.user, .assistant])
        #expect(
            recorder.routedConversations[1].map(\.text) == [
                "open my calendar", "answer to open my calendar",
            ]
        )
    }

    @Test("Turning follow-ups off isolates every request")
    func followUpsDisabled() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(recorder: recorder),
            preferences: makePreferences(followUps: false)
        )

        for _ in 0..<2 {
            await controller.handle(.startDictation)
            await controller.handle(.stopDictation)
        }

        #expect(recorder.routedConversations == [[], []])
    }

    @Test("Outward control is confirmed and records the approval")
    func outwardControlApproval() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                route: { _, _, _, _ in
                    .control(
                        goal: "send the draft to André",
                        risk: .externalCommunication
                    )
                },
                automation: AutomationClient { request, handler in
                    recorder.recordAutomation(request)
                    handler.onStep(.done("Sent."))
                }
            ),
            preferences: makePreferences(control: true)
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        let ran = await waitUntil { !recorder.automationRequests.isEmpty }

        #expect(ran)
        #expect(
            recorder.confirmations == [
                "Send this externally?\n\nsend the draft to André"
            ]
        )
        #expect(recorder.automationRequests.first?.userApproved == true)
        #expect(recorder.automationRequests.first?.risk == .externalCommunication)
    }

    @Test("The local policy upgrades an incorrectly read-only send request")
    func localRiskBackstop() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                route: { _, _, _, _ in
                    .control(goal: "send it to João", risk: .readOnly)
                },
                automation: AutomationClient { request, _ in
                    recorder.recordAutomation(request)
                }
            ),
            preferences: makePreferences(control: true)
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)
        let ran = await waitUntil { !recorder.automationRequests.isEmpty }

        #expect(ran)
        #expect(recorder.confirmations.count == 1)
        #expect(recorder.automationRequests.first?.risk == .externalCommunication)
        #expect(recorder.automationRequests.first?.userApproved == true)
    }

    @Test("Cancelling approval prevents control")
    func approvalCancellation() async {
        let recorder = CommandRecorder()
        let controller = CommandController(
            clients: makeCommandClients(
                recorder: recorder,
                route: { _, _, _, _ in
                    .control(goal: "delete the draft", risk: .destructive)
                },
                automation: AutomationClient { request, _ in
                    recorder.recordAutomation(request)
                },
                confirm: { _ in false }
            ),
            preferences: makePreferences(control: true)
        )

        await controller.handle(.startDictation)
        await controller.handle(.stopDictation)

        #expect(recorder.automationRequests.isEmpty)
        await #expect(controller.currentActivity == .answer("Cancelled."))
    }
}
