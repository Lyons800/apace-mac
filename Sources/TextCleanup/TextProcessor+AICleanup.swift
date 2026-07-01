import ApaceClients

extension TextProcessorClient {
    /// AI text cleanup, on-device first with a bring-your-own-key fallback: it uses
    /// Apple Intelligence when that's available, otherwise the user's own API key if
    /// they've set one, and otherwise leaves the text untouched. `apiKey` is read fresh
    /// each call so a key added in settings takes effect immediately.
    public static func aiCleanup(apiKey: @escaping @Sendable () -> String?) -> TextProcessorClient {
        TextProcessorClient { text in
            guard !text.isEmpty else { return text }

            if AppleIntelligenceCleaner.isAvailable {
                return await AppleIntelligenceCleaner.clean(text)
            }
            if let key = apiKey(), !key.isEmpty {
                return await AnthropicCleaner.clean(text, apiKey: key)
            }
            return text
        }
    }
}
