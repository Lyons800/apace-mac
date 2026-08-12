import Foundation

/// Records a short pronunciation sample and returns the unbiased spelling produced by
/// the currently selected recogniser. The settings feature stores that hypothesis as
/// an acoustic alias for the canonical term the user entered.
public struct PronunciationLearningClient: Sendable {
    public var start: @Sendable () throws -> Void
    public var finish: @Sendable () async throws -> String
    public var cancel: @Sendable () -> Void

    public init(
        start: @escaping @Sendable () throws -> Void,
        finish: @escaping @Sendable () async throws -> String,
        cancel: @escaping @Sendable () -> Void
    ) {
        self.start = start
        self.finish = finish
        self.cancel = cancel
    }

    public static let unavailable = PronunciationLearningClient(
        start: {},
        finish: { "" },
        cancel: {}
    )
}
