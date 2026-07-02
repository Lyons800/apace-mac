import Foundation

/// Cleans up a transcript with Anthropic's API — the fallback when Apple Intelligence
/// isn't available. Uses the user's own key, calls the Messages endpoint directly (no
/// SDK on macOS), and defaults to Haiku: this fires once per dictation, so it needs to
/// be fast and cheap, which is exactly Haiku's lane.
enum AnthropicCleaner {
    static let model = "claude-haiku-4-5"
    private static let endpoint = "https://api.anthropic.com/v1/messages"

    static func clean(_ text: String, apiKey: String) async -> String {
        guard let url = URL(string: endpoint) else { return text }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = RequestBody(
            model: model,
            maxTokens: 2048,
            system: CleanupInstructions.system,
            messages: [Message(role: "user", content: text)]
        )
        guard let encoded = try? JSONEncoder().encode(body) else { return text }
        request.httpBody = encoded

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                (response as? HTTPURLResponse)?.statusCode == 200,
                let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
                let cleaned = decoded.content.first(where: { $0.type == "text" })?.text,
                !cleaned.isEmpty
            else { return text }
            return cleaned
        } catch {
            // Best-effort: never lose the transcript to a network failure.
            return text
        }
    }

    private struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model, system, messages
            case maxTokens = "max_tokens"
        }
    }

    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct ResponseBody: Decodable {
        let content: [Block]

        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }
}
