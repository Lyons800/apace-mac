import Foundation

public struct DictationHealthSnapshot: Sendable, Equatable {
    public var lastHotkey: String?
    public var lastHotkeyAt: Date?
    public var microphoneName: String?
    public var inputLevel: Double = 0
    public var lastRecordingDuration: TimeInterval?
    public var lastTranscriptionDuration: TimeInterval?
    public var lastInsertion: String?
    public var lastError: String?

    public init() {}
}

public enum DictationHealthEvent: Sendable {
    case hotkey(String)
    case microphone(String)
    case inputLevel(Double)
    case recordingFinished(TimeInterval)
    case transcriptionFinished(TimeInterval)
    case insertion(String)
    case error(String)
    case clearError
}

/// Local operational diagnostics only: no audio and no transcript content is stored.
public final class DictationHealthRecorder: @unchecked Sendable {
    public static let shared = DictationHealthRecorder()

    private let lock = NSLock()
    private var value = DictationHealthSnapshot()

    public var snapshot: DictationHealthSnapshot { lock.withLock { value } }

    public func record(_ event: DictationHealthEvent) {
        lock.withLock {
            switch event {
            case .hotkey(let description):
                value.lastHotkey = description
                value.lastHotkeyAt = Date()
            case .microphone(let name): value.microphoneName = name
            case .inputLevel(let level): value.inputLevel = min(max(level, 0), 1)
            case .recordingFinished(let duration): value.lastRecordingDuration = duration
            case .transcriptionFinished(let duration):
                value.lastTranscriptionDuration = duration
            case .insertion(let result): value.lastInsertion = result
            case .error(let message): value.lastError = message
            case .clearError: value.lastError = nil
            }
        }
    }
}

public struct DictationHealthClient: Sendable {
    public var record: @Sendable (DictationHealthEvent) -> Void

    public init(record: @escaping @Sendable (DictationHealthEvent) -> Void) {
        self.record = record
    }

    public static let disabled = DictationHealthClient(record: { _ in })
    public static let live = DictationHealthClient {
        DictationHealthRecorder.shared.record($0)
    }
}
