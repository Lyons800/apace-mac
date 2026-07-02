import Foundation

/// Answers a spoken command through Google's Gemini API, optionally attaching a
/// screenshot so the model can act on what's on screen. Uses a fast Flash model — this
/// is meant to feel interactive.
enum GeminiVision {
    // gemini-2.0-flash is fast and vision-capable today; move to gemini-3-flash when it
    // reaches general availability.
    private static let model = "gemini-2.0-flash"

    private static let system = """
        You are a concise voice assistant embedded in a macOS app. Answer the user's \
        spoken request directly. If a screenshot is attached, use what's on screen. \
        Keep answers short enough to read at a glance.
        """

    static func respond(question: String, image: Data?, apiKey: String) async throws -> String {
        let endpoint =
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: endpoint) else { return question }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        var parts = [Part(text: question, inlineData: nil)]
        if let image {
            parts.append(
                Part(
                    text: nil,
                    inlineData: InlineData(mimeType: "image/png", data: image.base64EncodedString())
                )
            )
        }
        let body = RequestBody(
            systemInstruction: Content(parts: [Part(text: system, inlineData: nil)]),
            contents: [Content(parts: parts)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            (response as? HTTPURLResponse)?.statusCode == 200,
            let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
            let text = decoded.candidates.first?.content.parts.first?.text
        else {
            return "Sorry — I couldn't reach Gemini just now."
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct RequestBody: Encodable {
        let systemInstruction: Content
        let contents: [Content]

        enum CodingKeys: String, CodingKey {
            case systemInstruction = "system_instruction"
            case contents
        }
    }

    private struct Content: Encodable, Decodable { let parts: [Part] }

    private struct Part: Encodable, Decodable {
        let text: String?
        let inlineData: InlineData?

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }
    }

    private struct InlineData: Encodable, Decodable {
        let mimeType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    private struct ResponseBody: Decodable {
        let candidates: [Candidate]

        struct Candidate: Decodable { let content: Content }
    }
}
