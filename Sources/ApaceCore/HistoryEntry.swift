import Foundation

/// Where a past dictation got to. Failed and interrupted sessions remain visible so the
/// user can retry them instead of losing the recording.
public enum HistoryEntryStatus: String, Sendable, Equatable, Codable {
    case processing
    case inserted
    case copiedToClipboard
    case failed

    public var isRecoverable: Bool {
        switch self {
        case .processing, .copiedToClipboard, .failed: true
        case .inserted: false
        }
    }
}

/// One past dictation. `rawText` preserves what the recogniser actually returned while
/// `text` is the quick/cleaned result presented to the user. `hasAudio` is true only
/// while recovery audio is retained for an interrupted or failed transcription.
public struct HistoryEntry: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public var text: String
    public let date: Date
    public var rawText: String?
    public var status: HistoryEntryStatus
    public var errorMessage: String?
    public var hasAudio: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        date: Date,
        rawText: String? = nil,
        status: HistoryEntryStatus = .inserted,
        errorMessage: String? = nil,
        hasAudio: Bool = false
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.rawText = rawText
        self.status = status
        self.errorMessage = errorMessage
        self.hasAudio = hasAudio
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, date, rawText, status, errorMessage, hasAudio
    }

    /// Older releases stored only id/text/date. Decode those entries as successful so
    /// upgrading never discards a user's existing history.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        text = try values.decode(String.self, forKey: .text)
        date = try values.decode(Date.self, forKey: .date)
        rawText = try values.decodeIfPresent(String.self, forKey: .rawText)
        status = try values.decodeIfPresent(HistoryEntryStatus.self, forKey: .status) ?? .inserted
        errorMessage = try values.decodeIfPresent(String.self, forKey: .errorMessage)
        hasAudio = try values.decodeIfPresent(Bool.self, forKey: .hasAudio) ?? false
    }
}
