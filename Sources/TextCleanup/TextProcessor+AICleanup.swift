import ApaceClients
import ApaceCore

extension TextProcessorClient {
    /// AI text cleanup routed to the user's chosen provider. On-device uses Apple
    /// Intelligence; the cloud providers each use the user's own key. The provider and
    /// key are read fresh each call so a change in settings takes effect immediately,
    /// and any failure (no key, unavailable, network) leaves the text untouched.
    public static func aiCleanup(
        provider: @escaping @Sendable () -> CleanupProvider,
        apiKey: @escaping @Sendable (CleanupProvider) -> String?
    ) -> TextProcessorClient {
        TextProcessorClient { text in
            guard !text.isEmpty else { return text }
            let provider = provider()

            switch provider {
            case .onDevice:
                guard AppleIntelligenceCleaner.isAvailable else { return text }
                return await AppleIntelligenceCleaner.clean(text)

            case .anthropic:
                guard let key = apiKey(provider), !key.isEmpty else { return text }
                return await AnthropicCleaner.clean(text, apiKey: key)

            case .groq:
                guard let key = apiKey(provider), !key.isEmpty else { return text }
                return await OpenAICompatibleCleaner.clean(text, apiKey: key, config: .groq)

            case .openai:
                guard let key = apiKey(provider), !key.isEmpty else { return text }
                return await OpenAICompatibleCleaner.clean(text, apiKey: key, config: .openai)

            case .gemini:
                guard let key = apiKey(provider), !key.isEmpty else { return text }
                return await GeminiCleaner.clean(text, apiKey: key)
            }
        }
    }
}
