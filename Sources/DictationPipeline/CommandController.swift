import ApaceClients
import ApaceCore
import Foundation

/// Coordinates one voice command: hold the command hotkey, speak, release — Apace
/// transcribes the request, optionally grabs a screenshot, asks the chosen model, and
/// shows the answer in the notch. It's the command-mode sibling of ``DictationController``
/// and, like it, is an actor so its state is mutated from one place.
public actor CommandController {
    private let clients: CommandClients
    private var activity: CommandActivity = .idle
    private var captureTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?

    private let continuation: AsyncStream<CommandActivity>.Continuation
    public nonisolated let activities: AsyncStream<CommandActivity>

    public init(clients: CommandClients) {
        self.clients = clients
        (activities, continuation) = AsyncStream.makeStream()
        continuation.yield(.idle)
    }

    /// Drives the controller from the command hotkey for the app's lifetime.
    public func run() async {
        for await intent in clients.hotkey.intents() {
            await handle(intent)
        }
    }

    func handle(_ intent: HotkeyIntent) async {
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
        guard CommandPreference.isEnabled else { return }
        guard case .idle = activity else { return }
        resetTask?.cancel()
        do {
            let stream = try clients.audio.start()
            captureTask = Task { for await _ in stream {} }  // drain; final pass uses the buffer
            emit(.listening(partial: ""))
        } catch {
            fail("Couldn't access the microphone.")
        }
    }

    private func finish() async {
        guard case .listening = activity else { return }
        captureTask?.cancel()
        let samples = clients.audio.stop()
        emit(.thinking)

        let question = ((try? await clients.transcriber.transcribe(samples)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            fail("I didn't catch that.")
            return
        }

        let screenshot = CommandPreference.usesVision ? clients.screen.capture() : nil
        do {
            let answer = try await clients.vision.respond(question, screenshot)
            emit(.answer(answer))
        } catch {
            emit(.failed("Couldn't get an answer just now."))
        }
        scheduleReset()
    }

    private func cancel() {
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
}
