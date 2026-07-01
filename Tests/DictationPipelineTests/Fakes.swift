import ApaceClients
import ApaceCore
import Foundation

/// Errors the fake adapters can be told to throw, to exercise the failure paths.
enum FakeError: Error {
    case microphoneUnavailable
    case transcriptionFailed
}

/// Thread-safe scratchpad the fakes write to. The ports are synchronous `@Sendable`
/// closures, so we can't reach an actor from inside `audio.stop`; a small locked box
/// is the simplest way to record calls safely across the concurrent tasks the
/// controller spawns.
final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _inserted: [String] = []
    private var _stopCount = 0

    var inserted: [String] { lock.withLock { _inserted } }
    var stopCount: Int { lock.withLock { _stopCount } }

    func append(inserted text: String) { lock.withLock { _inserted.append(text) } }
    func recordStop() { lock.withLock { _stopCount += 1 } }
}

/// Builds a set of fake ports wired to `recorder`. Each behaviour is a parameter so a
/// test states only what it cares about and takes sensible defaults for the rest.
func makeClients(
    recorder: Recorder,
    startThrows: Bool = false,
    partials: [String] = [],
    transcribe: @escaping @Sendable ([Float]) async throws -> String = { _ in "hello world" },
    process: @escaping @Sendable (String) -> String = { $0 },
    hotkey: HotkeyClient = HotkeyClient(intents: { AsyncStream { $0.finish() } })
) -> DictationClients {
    let audio = AudioCaptureClient(
        start: {
            if startThrows { throw FakeError.microphoneUnavailable }
            return AsyncStream { $0.finish() }
        },
        stop: {
            recorder.recordStop()
            return [0.1, 0.2, 0.3]
        }
    )

    let transcriber = TranscriberClient(
        stream: { _ in
            AsyncThrowingStream { continuation in
                for partial in partials {
                    continuation.yield(ASRUpdate(text: partial, isFinal: false))
                }
                continuation.finish()
            }
        },
        transcribe: transcribe
    )

    let inserter = TextInserterClient(insert: { recorder.append(inserted: $0) })
    let processor = TextProcessorClient { process($0) }

    return DictationClients(
        audio: audio,
        transcriber: transcriber,
        hotkey: hotkey,
        inserter: inserter,
        processor: processor
    )
}

/// Polls `predicate` until it holds or a short budget elapses. Used only for the
/// streaming-preview path, where partials are applied on a background task; every
/// other path is awaited directly and needs no polling.
func waitUntil(_ predicate: @Sendable () async -> Bool) async -> Bool {
    for _ in 0..<200 {
        if await predicate() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return await predicate()
}
