import Foundation

/// Cleans up a transcript through any OpenAI-compatible chat endpoint. Groq and OpenAI
/// share this exact wire format — only the base URL and model differ — so one client
/// covers both. Defaults to small, fast models: this runs once per dictation.
enum OpenAICompatibleCleaner {
    struct Config: Sendable {
        let endpoint: String
        let model: String

        static let groq = Config(
            endpoint: "https://api.groq.com/openai/v1/chat/completions",
            model: "llama-3.1-8b-instant"
        )
        static let openai = Config(
            endpoint: "https://api.openai.com/v1/chat/completions",
            model: "gpt-4o-mini"
        )
    }

    static func clean(_ text: String, apiKey: String, config: Config) async -> String {
        guard let url = URL(string: config.endpoint) else { return text }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = RequestBody(
            model: config.model,
            temperature: 0,
            messages: [
                Message(role: "system", content: CleanupInstructions.system),
                Message(role: "user", content: text),
            ]
        )
        guard let encoded = try? JSONEncoder().encode(body) else { return text }
        request.httpBody = encoded

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                (response as? HTTPURLResponse)?.statusCode == 200,
                let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
                let content = decoded.choices.first?.message.content,
                !content.isEmpty
            else { return text }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return text
        }
    }

    private struct RequestBody: Encodable {
        let model: String
        let temperature: Double
        let messages: [Message]
    }

    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct ResponseBody: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message

            struct Message: Decodable { let content: String }
        }
    }
}
