import Foundation

/// A user intent emitted by the global hotkey layer, decoupled from the physical
/// key and gesture. Push-to-talk, toggle, and the hybrid hold/lock model all map
/// onto this small vocabulary, so the rest of the app never reasons about key codes.
public enum HotkeyIntent: Equatable, Sendable {
    case startDictation
    case stopDictation
    case toggleDictation
    case cancel
}

/// A chunk of 16 kHz mono float PCM — the format every transcription engine expects.
///
/// It is a `Sendable` value type on purpose: audio is produced on a real-time audio
/// thread and consumed on the async/ML side, and copying the samples out into an
/// immutable value is the safe way to cross that boundary (never share the transient
/// `AVAudioPCMBuffer` itself).
public struct AudioChunk: Sendable, Equatable {
    public let samples: [Float]

    public init(samples: [Float]) {
        self.samples = samples
    }
}

/// One update from a streaming transcription engine.
///
/// The three engines we support expose three different streaming idioms; the
/// adapters normalise them all to a stream of these, where `isFinal` is the single
/// flag that distinguishes a committed segment from a throwaway volatile partial.
public struct ASRUpdate: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}
