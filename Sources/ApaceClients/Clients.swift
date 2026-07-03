import ApaceCore
import Foundation

// The "ports" of the architecture: every capability the app needs from the outside
// world is expressed here as a struct of closures rather than a protocol. Concrete
// `live` adapters (in AudioCapture / Transcription / SystemServices) plug into these
// at the app's composition root; tests and previews swap individual closures in
// place without writing a whole conforming type. This is what makes the dictation
// flow drivable with synthetic audio and synthetic hotkeys — zero hardware.

/// Captures microphone audio as 16 kHz mono chunks.
public struct AudioCaptureClient: Sendable {
    /// Begins capturing. The returned stream is the level channel: it yields converted
    /// chunks as they arrive and drops the oldest under back-pressure, so a slow
    /// consumer never stalls the real-time audio thread.
    public var start: @Sendable () throws -> AsyncStream<AudioChunk>
    /// A snapshot of everything recorded so far, without stopping. The coordinator uses
    /// this to re-transcribe the recent audio for a live preview that — unlike a
    /// streaming recogniser — doesn't reset when the speaker pauses.
    public var samples: @Sendable () -> [Float]
    /// Stops capturing and returns the complete loss-less buffer for the final pass —
    /// this is what gets transcribed and inserted.
    public var stop: @Sendable () -> [Float]

    public init(
        start: @escaping @Sendable () throws -> AsyncStream<AudioChunk>,
        samples: @escaping @Sendable () -> [Float],
        stop: @escaping @Sendable () -> [Float]
    ) {
        self.start = start
        self.samples = samples
        self.stop = stop
    }
}

/// Turns audio into text.
public struct TranscriberClient: Sendable {
    /// Live, streaming transcription for the on-screen preview (volatile + final).
    public var stream: @Sendable (AsyncStream<AudioChunk>) -> AsyncThrowingStream<ASRUpdate, Error>
    /// A single accurate pass over the whole utterance; its result is what we insert.
    public var transcribe: @Sendable ([Float]) async throws -> String

    public init(
        stream:
            @escaping @Sendable (AsyncStream<AudioChunk>) -> AsyncThrowingStream<ASRUpdate, Error>,
        transcribe: @escaping @Sendable ([Float]) async throws -> String
    ) {
        self.stream = stream
        self.transcribe = transcribe
    }
}

/// Emits user intents from the global hotkey. The live adapter owns a `CGEvent` tap
/// and is responsible for the robustness work (re-enabling a disabled tap, never
/// getting stuck "on" after a missed key-up).
public struct HotkeyClient: Sendable {
    public var intents: @Sendable () -> AsyncStream<HotkeyIntent>

    public init(intents: @escaping @Sendable () -> AsyncStream<HotkeyIntent>) {
        self.intents = intents
    }
}

/// Inserts text into the frontmost application.
public struct TextInserterClient: Sendable {
    /// Inserts `text` at the cursor — paste + ⌘V primary, with accessibility and
    /// synthetic-keystroke fallbacks handled inside the live adapter.
    public var insert: @Sendable (String) async -> Void
    /// Replaces the last `deleteCount` characters just inserted with `text` — used to
    /// swap the quick transcript for the AI-cleaned one once it's ready.
    public var replaceLast: @Sendable (_ deleteCount: Int, _ text: String) async -> Void

    public init(
        insert: @escaping @Sendable (String) async -> Void,
        replaceLast: @escaping @Sendable (_ deleteCount: Int, _ text: String) async -> Void = {
            _,
            _ in
        }
    ) {
        self.insert = insert
        self.replaceLast = replaceLast
    }
}
