/// The port for post-processing a finished transcript before it's inserted — custom
/// vocabulary today, AI cleanup later. It's a single async transform so the
/// coordinator doesn't need to know what's behind it.
public struct TextProcessorClient: Sendable {
    public var process: @Sendable (String) async -> String

    public init(process: @escaping @Sendable (String) async -> String) {
        self.process = process
    }

    /// Returns the text unchanged — the default before any processing is configured,
    /// and the natural stand-in for tests.
    public static let passthrough = TextProcessorClient { $0 }
}
