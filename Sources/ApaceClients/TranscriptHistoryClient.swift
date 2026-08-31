import ApaceCore
import Foundation

/// Pipeline-facing seam for durable transcript recovery. Tests use `.disabled`; the app
/// uses `.live`, keeping storage side effects out of the dictation state-machine tests.
public struct TranscriptHistoryClient: Sendable {
    public var begin: @Sendable ([Float]) -> UUID?
    public var update:
        @Sendable (
            _ id: UUID,
            _ rawText: String?,
            _ text: String?,
            _ status: HistoryEntryStatus?,
            _ errorMessage: String?,
            _ discardAudio: Bool
        ) -> Void

    public init(
        begin: @escaping @Sendable ([Float]) -> UUID?,
        update:
            @escaping @Sendable (
                UUID, String?, String?, HistoryEntryStatus?, String?, Bool
            ) -> Void
    ) {
        self.begin = begin
        self.update = update
    }

    public static let disabled = TranscriptHistoryClient(
        begin: { _ in nil },
        update: { _, _, _, _, _, _ in }
    )

    public static let live = TranscriptHistoryClient(
        begin: { TranscriptHistory.begin(samples: $0) },
        update: { id, rawText, text, status, errorMessage, discardAudio in
            TranscriptHistory.update(
                id: id,
                rawText: rawText,
                text: text,
                status: status,
                errorMessage: errorMessage,
                discardAudio: discardAudio
            )
        }
    )
}
