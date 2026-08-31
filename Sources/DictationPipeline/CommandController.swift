import ApaceClients
import ApaceCore
import CoreGraphics
import Foundation
import os

/// Coordinates one voice command: hold the command hotkey, speak, release — Apace
/// transcribes the request, optionally grabs a screenshot, asks the chosen model, and
/// shows the answer in the notch. It's the command-mode sibling of ``DictationController``
/// and, like it, is an actor so its state is mutated from one place.
public actor CommandController {
    private let clients: CommandClients
    private let preferences: CommandPreferencesReader
    private var activity: CommandActivity = .idle
    private var captureTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    /// The in-flight computer-use loop, kept so a new gesture can abort it.
    private var controlTask: Task<Void, Never>?
    private var conversation = CommandConversation()
    private let now: @Sendable () -> Date
    private let conversationLifetime: TimeInterval

    private let continuation: AsyncStream<CommandActivity>.Continuation
    public nonisolated let activities: AsyncStream<CommandActivity>
    private let conversationContinuation: AsyncStream<[CommandTurn]>.Continuation
    public nonisolated let conversations: AsyncStream<[CommandTurn]>

    private static let log = Logger(subsystem: "so.apace", category: "command")

    public init(
        clients: CommandClients,
        preferences: CommandPreferencesReader = .live,
        now: @escaping @Sendable () -> Date = { Date() },
        conversationLifetime: TimeInterval = CommandConversation.defaultLifetime
    ) {
        self.clients = clients
        self.preferences = preferences
        self.now = now
        self.conversationLifetime = conversationLifetime
        (activities, continuation) = AsyncStream.makeStream()
        (conversations, conversationContinuation) = AsyncStream.makeStream()
        continuation.yield(.idle)
        conversationContinuation.yield([])
    }

    /// The current activity. Exposed mainly for tests and diagnostics; production code
    /// observes ``activities`` instead.
    public var currentActivity: CommandActivity { activity }
    public var currentConversation: [CommandTurn] { conversation.turns }

    public func resetConversation() {
        conversation.reset()
        conversationContinuation.yield([])
    }

    /// Drives the controller from the command hotkey for the app's lifetime.
    public func run() async {
        for await intent in clients.hotkey.intents() {
            await handle(intent)
        }
    }

    public func handle(_ intent: HotkeyIntent) async {
        switch intent {
        case .startDictation:
            start()
        case .stopDictation:
            await finish()
        case .toggleDictation, .cancel:
            cancel()
        }
    }

    private func start() {
        guard preferences.isEnabled() else { return }
        // A stale answer or failure on the notch — or a running control loop — must not
        // block the next command; only an already-listening session does.
        if case .listening = activity { return }
        abortControl()
        resetTask?.cancel()
        do {
            let stream = try clients.audio.start()
            captureTask = Task { for await _ in stream {} }  // drain; final pass uses the buffer
            emit(.listening(partial: ""))
        } catch {
            Self.log.error("microphone start failed: \(error)")
            fail("Couldn't access the microphone.")
        }
    }

    private func finish() async {
        guard case .listening = activity else { return }
        captureTask?.cancel()
        let samples = clients.audio.stop()
        emit(.thinking)

        // The same gates dictation uses: too short to be speech, or no speech energy —
        // don't transcribe silence, which makes the model hallucinate a command.
        guard samples.count >= DictationController.minimumSamples,
            DictationController.hasSpeech(samples)
        else {
            fail("I didn't catch that.")
            return
        }

        let question: String
        do {
            question = try await clients.transcriber.transcribe(samples)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            Self.log.error("command transcription failed: \(error)")
            fail("Transcription failed — try again.")
            return
        }
        guard !question.isEmpty else {
            fail("I didn't catch that.")
            return
        }

        await runRouted(question)
    }

    /// One router round trip decides the command's shape: an answer for the notch,
    /// text for the focused field, or escalation to the control loop. A router
    /// failure falls back to the plain answer path so Q&A never breaks.
    private func runRouted(_ question: String) async {
        if !preferences.followUpsEnabled() { resetConversation() }
        let previousTurns = conversation.context(at: now(), lifetime: conversationLifetime)
        appendTurn(.user, question)
        let field = clients.focus.focusedField()
        let screenshot =
            preferences.usesVision() && preferences.provider().supportsImages
            ? clients.screen.capture() : nil
        let decision: CommandDecision
        do {
            decision = try await clients.router.route(question, field, screenshot, previousTurns)
        } catch {
            Self.log.error("router failed, falling back to answer: \(error)")
            await runAnswer(question, conversation: previousTurns)
            scheduleReset()
            return
        }
        switch decision {
        case .answer(let text):
            appendTurn(.assistant, text)
            emit(.answer(text))
            scheduleReset()
        case .insert(let text, let replacesDraft):
            if replacesDraft {
                // Select the field's draft so the paste replaces it, and give the
                // frontmost app a beat to apply the selection before ⌘V.
                clients.control.perform(.key(0, .maskCommand))  // ⌘A
                try? await Task.sleep(for: .milliseconds(80))
            }
            let result = await clients.inserter.insert(text)
            let response =
                result == .inserted
                ? text : "Paste was blocked — the result is on your clipboard."
            appendTurn(.assistant, response)
            emit(.answer(response))
            scheduleReset()
        case .control(let goal, let risk):
            if preferences.controlEnabled() {
                await runControl(goal, risk: risk)
            } else {
                let message =
                    "Turn on “Let it control my Mac” (Settings → Commands & Actions) for that."
                appendTurn(.assistant, message)
                emit(.answer(message))
                scheduleReset()
            }
        }
    }

    /// Answers the command with the vision model, with a screenshot only when the chosen
    /// provider can actually look at one.
    private func runAnswer(_ question: String, conversation: [CommandTurn]) async {
        let screenshot =
            preferences.usesVision() && preferences.provider().supportsImages
            ? clients.screen.capture() : nil
        do {
            let prompt = Self.followUpPrompt(question: question, conversation: conversation)
            let answer = try await clients.vision.respond(prompt, screenshot)
            appendTurn(.assistant, answer)
            emit(.answer(answer))
        } catch {
            Self.log.error("vision answer failed: \(error)")
            let message = "Couldn't get an answer just now."
            appendTurn(.assistant, message)
            emit(.failed(message))
        }
    }

    /// Drives the Mac to carry out the command via the computer-use loop, mirroring its
    /// progress into the notch and routing its confirmation prompts to the app. Runs in
    /// a stored task so a new gesture (or cancel) can abort a runaway loop.
    private func runControl(_ goal: String, risk: CommandActionRisk) async {
        let effectiveRisk = CommandActionRisk.resolved(proposed: risk, goal: goal)
        let requiresApproval = effectiveRisk.requiresApproval
        if requiresApproval {
            let summary = "\(effectiveRisk.approvalTitle)\n\n\(goal)"
            guard await clients.confirm(summary) else {
                appendTurn(.assistant, "Cancelled.")
                emit(.answer("Cancelled."))
                scheduleReset()
                return
            }
        }

        appendTurn(.assistant, "Running: \(goal)")
        let handler = AutomationHandler(
            onStep: { [weak self] step in
                Task { await self?.apply(step) }
            },
            confirm: clients.confirm
        )
        let automation = clients.automation
        let request = AutomationRequest(
            goal: goal,
            risk: effectiveRisk,
            userApproved: requiresApproval
        )
        controlTask = Task { [weak self] in
            await automation.run(request, handler)
            await self?.controlFinished()
        }
    }

    private func controlFinished() {
        controlTask = nil
        // If a new command already took over the notch, leave it alone.
        if case .listening = activity { return }
        scheduleReset()
    }

    private func apply(_ step: AutomationStep) {
        // A late step from an aborted loop must not clobber the session that replaced it.
        if case .listening = activity { return }
        switch step {
        case .thinking: emit(.thinking)
        case .acting(let description): emit(.answer(description))
        case .done(let summary):
            appendTurn(.assistant, summary)
            emit(.answer(summary))
        case .failed(let message):
            Self.log.error("automation failed: \(message, privacy: .public)")
            appendTurn(.assistant, message)
            emit(.failed(message))
        }
    }

    private func abortControl() {
        controlTask?.cancel()
        controlTask = nil
    }

    private func cancel() {
        abortControl()
        captureTask?.cancel()
        _ = clients.audio.stop()
        emit(.idle)
    }

    private func fail(_ message: String) {
        captureTask?.cancel()
        _ = clients.audio.stop()
        emit(.failed(message))
        scheduleReset()
    }

    /// Clears the notch a few seconds after an answer or error so it doesn't linger.
    private func scheduleReset() {
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled { await self?.emit(.idle) }
        }
    }

    private func emit(_ next: CommandActivity) {
        activity = next
        continuation.yield(next)
    }

    private func appendTurn(_ role: CommandTurn.Role, _ text: String) {
        conversation.append(role: role, text: text, at: now())
        conversationContinuation.yield(conversation.turns)
    }

    private static func followUpPrompt(
        question: String,
        conversation: [CommandTurn]
    ) -> String {
        guard !conversation.isEmpty else { return question }
        let turns = conversation.map {
            "\($0.role == .user ? "User" : "Apace"): \($0.text)"
        }
        return """
            Continue this recent conversation. Resolve short follow-ups from it, but do not \
            invent missing details.

            \(turns.joined(separator: "\n"))

            User: \(question)
            """
    }
}
