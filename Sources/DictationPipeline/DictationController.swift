import ApaceClients
import ApaceCore
import Foundation

/// Coordinates one dictation from end to end: it turns hotkey intents into side
/// effects on the live ports (microphone, transcriber, text inserter) while keeping
/// the ``DictationStateMachine`` as the single source of truth for *what state we're
/// in*. The controller is the impure shell around that pure core.
///
/// It is an `actor` so the state machine and the in-flight tasks are mutated from one
/// place, even though intents, streaming partials, and the final pass all arrive
/// concurrently. Observers (the UI) subscribe to ``states`` rather than reaching in.
public actor DictationController {
    private let clients: DictationClients
    private let machine = DictationStateMachine()
    private var state: DictationState = .idle

    /// The live preview stream is best-effort and runs for the duration of a single
    /// listening session; cancelling it is how we tear the preview down on stop.
    private var partialsTask: Task<Void, Never>?

    private let continuation: AsyncStream<DictationState>.Continuation

    /// Every state transition, in order, starting with `.idle`. The UI republishes
    /// this onto an `@Observable` store; nothing outside the actor mutates state.
    public nonisolated let states: AsyncStream<DictationState>

    public init(clients: DictationClients) {
        self.clients = clients
        (states, continuation) = AsyncStream.makeStream()
        continuation.yield(.idle)
    }

    /// The current state of the dictation. Exposed mainly for tests and diagnostics;
    /// production code observes ``states`` instead.
    public var currentState: DictationState { state }

    /// Drives the controller from the hotkey port. Runs until the intent stream ends
    /// (i.e. for the lifetime of the app), so it is typically spawned in a `Task`.
    public func run() async {
        for await intent in clients.hotkey.intents() {
            await handle(intent)
        }
    }

    /// Handles a single intent. Public so the app can also inject intents from sources
    /// other than the hotkey (menu item, scripting) and so tests can drive the flow
    /// deterministically without racing on a stream.
    public func handle(_ intent: HotkeyIntent) async {
        switch intent {
        case .startDictation:
            await start()
        case .stopDictation:
            await finish()
        case .toggleDictation:
            if isListening {
                await finish()
            } else {
                await start()
            }
        case .cancel:
            cancel()
        }
    }

    // MARK: - Transitions

    private func start() async {
        guard !isActive else { return }
        apply(.startRequested)
        do {
            let audio = try clients.audio.start()
            partialsTask = Task { [weak self] in
                await self?.streamPartials(from: audio)
            }
        } catch {
            cleanUp()
            apply(.failed(Self.microphoneErrorMessage))
        }
    }

    private func finish() async {
        guard isListening else { return }
        apply(.stopRequested)
        partialsTask?.cancel()
        let samples = clients.audio.stop()
        do {
            let text = try await clients.transcriber.transcribe(samples)
            apply(.finalTranscript(text))
            if case .inserting(let finalText) = state {
                await clients.inserter.insert(finalText)
                apply(.textInserted)
            }
        } catch {
            apply(.failed(Self.transcriptionErrorMessage))
        }
    }

    private func cancel() {
        guard isActive else { return }
        cleanUp()
        apply(.cancelled)
    }

    /// Forwards volatile partials to the state machine for the live preview. Errors
    /// here are swallowed on purpose: the preview is disposable, and the accurate
    /// final pass in ``finish()`` is what the user actually gets.
    private func streamPartials(from audio: AsyncStream<AudioChunk>) async {
        do {
            for try await update in clients.transcriber.stream(audio) where !update.isFinal {
                apply(.partialTranscript(update.text))
            }
        } catch {
            // Preview only — ignore and let the final pass stand.
        }
    }

    // MARK: - Helpers

    private func apply(_ event: DictationEvent) {
        state = machine.reduce(state, on: event)
        continuation.yield(state)
    }

    private func cleanUp() {
        partialsTask?.cancel()
        _ = clients.audio.stop()
    }

    private var isListening: Bool {
        if case .listening = state { return true }
        return false
    }

    /// Whether a dictation is currently in flight (anything but idle or a past failure).
    private var isActive: Bool {
        switch state {
        case .idle, .failed:
            return false
        case .listening, .transcribing, .inserting:
            return true
        }
    }

    static let microphoneErrorMessage = "Couldn't access the microphone."
    static let transcriptionErrorMessage = "Transcription failed. Please try again."
}
