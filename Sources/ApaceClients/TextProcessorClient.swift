/// The port for post-processing a finished transcript before it's inserted. It exposes
/// two passes: `quick` is a fast, synchronous tidy (no model) that's safe to insert
/// immediately, and `process` is the full pass (including any AI cleanup) that may take
/// a moment. The coordinator inserts `quick` right away and refines with `process` in the
/// background, so cleanup never makes insertion wait.
public struct TextProcessorClient: Sendable {
    public var process: @Sendable (String) async -> String
    public var quick: @Sendable (String) -> String

    public init(
        process: @escaping @Sendable (String) async -> String,
        quick: @escaping @Sendable (String) -> String = { $0 }
    ) {
        self.process = process
        self.quick = quick
    }

    /// Returns the text unchanged — the default before any processing is configured,
    /// and the natural stand-in for tests.
    public static let passthrough = TextProcessorClient(process: { $0 }, quick: { $0 })
}
