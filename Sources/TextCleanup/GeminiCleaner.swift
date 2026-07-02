import Foundation

/// Cleans up a transcript through Google's Gemini API. Its request shape differs from
/// the OpenAI-compatible ones, so it gets its own small client. The key goes in the
/// `x-goog-api-key` header rather than the URL, so it isn't logged in request URLs.
enum GeminiCleaner {
    private static let model = "gemini-2.0-flash"

    static func clean(_ text: String, apiKey: String) async -> String {
        let endpoint =
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: endpoint) else { return text }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body = RequestBody(
            systemInstruction: .init(parts: [.init(text: CleanupInstructions.system)]),
            contents: [.init(parts: [.init(text: text)])],
            generationConfig: .init(temperature: 0)
        )
        guard let encoded = try? JSONEncoder().encode(body) else { return text }
        request.httpBody = encoded

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                (response as? HTTPURLResponse)?.statusCode == 200,
                let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
                let content = decoded.candidates.first?.content.parts.first?.text,
                !content.isEmpty
            else { return text }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return text
        }
    }

    private struct RequestBody: Encodable {
        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig

        enum CodingKeys: String, CodingKey {
            case systemInstruction = "system_instruction"
            case contents
            case generationConfig
        }

        struct Content: Encodable { let parts: [Part] }
        struct Part: Encodable { let text: String }
        struct GenerationConfig: Encodable { let temperature: Double }
    }

    private struct ResponseBody: Decodable {
        let candidates: [Candidate]

        struct Candidate: Decodable {
            let content: Content

            struct Content: Decodable {
                let parts: [Part]

                struct Part: Decodable { let text: String }
            }
        }
    }
}
