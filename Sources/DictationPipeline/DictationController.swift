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
    /// Reads the capture stream to sample the microphone level and forward chunks on
    /// to the transcriber.
    private var captureTask: Task<Void, Never>?

    private let continuation: AsyncStream<DictationState>.Continuation
    private let levelContinuation: AsyncStream<Double>.Continuation

    /// Every state transition, in order, starting with `.idle`. The UI republishes
    /// this onto an `@Observable` store; nothing outside the actor mutates state.
    public nonisolated let states: AsyncStream<DictationState>

    /// A normalized 0...1 microphone level sampled while listening, for the waveform.
    /// It's a separate channel from ``states`` because it changes far too often to be
    /// domain state — the UI throttles it, the state machine never sees it.
    public nonisolated let levels: AsyncStream<Double>

    public init(clients: DictationClients) {
        self.clients = clients
        (states, continuation) = AsyncStream.makeStream()
        (levels, levelContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(4))
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
            // Tee the capture stream: sample the level for the waveform here, and
            // forward each chunk on to the transcriber's preview.
            let (forTranscriber, forward) = AsyncStream<AudioChunk>.makeStream()
            captureTask = Task { [levelContinuation, forward] in
                for await chunk in audio {
                    levelContinuation.yield(Self.level(of: chunk.samples))
                    forward.yield(chunk)
                }
                forward.finish()
            }
            partialsTask = Task { [weak self] in
                await self?.streamPartials(from: forTranscriber)
            }
        } catch {
            cleanUp()
            apply(.failed(Self.microphoneErrorMessage))
        }
    }

    private func finish() async {
        guard isListening else { return }
        apply(.stopRequested)
        stopCapture()
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
        stopCapture()
        _ = clients.audio.stop()
    }

    /// Tears down the capture and preview tasks and drops the waveform back to silence.
    private func stopCapture() {
        partialsTask?.cancel()
        captureTask?.cancel()
        levelContinuation.yield(0)
    }

    /// Converts a chunk of samples to a normalized 0...1 loudness for the waveform.
    /// Speech RMS is tiny (~0.001–0.05), so a linear scale would sit on the floor;
    /// mapping through decibels spreads quiet speech across the visible range.
    static func level(of samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sumOfSquares: Float = 0
        for sample in samples {
            sumOfSquares += sample * sample
        }
        let rms = (sumOfSquares / Float(samples.count)).squareRoot()
        let decibels = 20 * log10(max(rms, 1e-7))
        let normalized = (decibels + 60) / 60
        return Double(min(max(normalized, 0), 1))
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
