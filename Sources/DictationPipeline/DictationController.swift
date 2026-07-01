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

    /// Re-transcribes the recent audio on a cadence to drive the live preview; runs for
    /// a single listening session and is cancelled on stop.
    private var previewTask: Task<Void, Never>?
    /// Samples the microphone level off the capture stream for the waveform.
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
            captureTask = Task { [levelContinuation] in
                for await chunk in audio {
                    levelContinuation.yield(Self.level(of: chunk.samples))
                }
            }
            previewTask = Task { [weak self] in
                await self?.runPreview()
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
            let raw = try await clients.transcriber.transcribe(samples)
            let text = await clients.processor.process(raw)
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

    /// Drives the live preview by re-transcribing the recent audio on a cadence. Unlike
    /// a streaming recogniser this never finalises (and resets) when the speaker pauses:
    /// a silent tick is simply skipped, so the last preview stays put. Best-effort — the
    /// accurate final pass in ``finish()`` is what the user actually gets.
    private func runPreview() async {
        var lastSampleCount = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Self.previewIntervalMS))
            if Task.isCancelled { return }

            let samples = clients.audio.samples()
            guard samples.count > 8_000 else { continue }  // need ~0.5s of audio
            guard samples.count - lastSampleCount > 1_600 else { continue }  // new audio
            lastSampleCount = samples.count
            guard Self.isLoudEnough(samples) else { continue }  // hold through a pause

            // Cap the preview to the recent window so per-tick latency stays bounded;
            // the final pass on stop still uses the whole recording.
            let window =
                samples.count > Self.previewWindowSamples
                ? Array(samples.suffix(Self.previewWindowSamples)) : samples
            guard let text = try? await clients.transcriber.transcribe(window), !text.isEmpty
            else { continue }
            apply(.partialTranscript(text))
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
        previewTask?.cancel()
        captureTask?.cancel()
        levelContinuation.yield(0)
    }

    static let previewIntervalMS = 700
    static let previewWindowSamples = 192_000  // ~12s at 16 kHz

    /// Whether the tail of the buffer carries speech energy — used to hold the preview
    /// steady through a pause instead of re-transcribing silence.
    static func isLoudEnough(_ samples: [Float]) -> Bool {
        let tail = samples.suffix(4_000)  // ~0.25s
        guard !tail.isEmpty else { return false }
        var sumOfSquares: Float = 0
        for sample in tail {
            sumOfSquares += sample * sample
        }
        let rms = (sumOfSquares / Float(tail.count)).squareRoot()
        return 20 * log10(max(rms, 1e-7)) > -45
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
