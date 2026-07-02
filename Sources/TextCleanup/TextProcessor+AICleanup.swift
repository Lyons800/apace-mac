import ApaceClients
import ApaceCore

extension TextProcessorClient {
    /// Warms up the on-device cleanup model so the first cleanup isn't cold: prewarm
    /// Apple Intelligence where available, otherwise load the local MLX model.
    public static func preloadOnDeviceCleanup() {
        if AppleIntelligenceCleaner.isAvailable {
            AppleIntelligenceCleaner.prewarm()
        } else {
            Task { await MLXCleaner.shared.preload() }
        }
    }

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

            let cleaned: String
            switch provider {
            case .onDevice:
                // Apple Intelligence where available (zero download); otherwise a small
                // local MLX model so on-device cleanup works on any Apple Silicon Mac.
                if AppleIntelligenceCleaner.isAvailable {
                    cleaned = await AppleIntelligenceCleaner.clean(text)
                } else {
                    cleaned = await MLXCleaner.shared.clean(text)
                }

            case .anthropic:
                guard let key = apiKey(provider), !key.isEmpty else { return text }
                cleaned = await AnthropicCleaner.clean(text, apiKey: key)

            case .groq:
                guard let key = apiKey(provider), !key.isEmpty else { return text }
                cleaned = await OpenAICompatibleCleaner.clean(text, apiKey: key, config: .groq)

            case .openai:
                guard let key = apiKey(provider), !key.isEmpty else { return text }
                cleaned = await OpenAICompatibleCleaner.clean(text, apiKey: key, config: .openai)

            case .gemini:
                guard let key = apiKey(provider), !key.isEmpty else { return text }
                cleaned = await GeminiCleaner.clean(text, apiKey: key)
            }

            // Reject an "answer" that no longer resembles what the user said.
            return CleanupGuard.preserve(original: text, cleaned: cleaned)
        }
    }
}
