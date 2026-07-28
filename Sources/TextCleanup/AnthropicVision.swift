import Foundation

/// Answers a spoken command through Anthropic's Messages API, optionally attaching a
/// screenshot. Raw HTTP (there's no official Swift SDK), mirroring the app's other
/// Anthropic integration in `ComputerUseAPI`.
enum AnthropicVision {
    static let model = "claude-opus-5"

    static let assistantSystem = """
        You are a concise voice assistant embedded in a macOS app. Answer the user's \
        spoken request directly. If a screenshot is attached, use what's on screen. \
        Keep answers short enough to read at a glance.
        """

    /// One Messages API round trip: system + question (+ optional PNG screenshot) in,
    /// the reply's text out. `effort: low` keeps a voice interaction snappy — these are
    /// short routing/answer/translation tasks, not deep reasoning.
    static func respond(
        question: String,
        image: Data?,
        apiKey: String,
        system: String = assistantSystem
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AnthropicVisionError.http(0, "bad endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var content: [ContentPart] = []
        if let image {
            content.append(
                ContentPart(
                    type: "image",
                    text: nil,
                    source: ImageSource(data: image.base64EncodedString())
                )
            )
        }
        content.append(ContentPart(type: "text", text: question, source: nil))
        let body = RequestBody(
            model: model,
            maxTokens: 4096,
            system: system,
            outputConfig: OutputConfig(effort: "low"),
            messages: [Message(role: "user", content: content)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message =
                (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error.message
                ?? String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw AnthropicVisionError.http(status, message)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        // Safety classifiers can decline with a 200 — check before reading content.
        guard decoded.stopReason != "refusal" else { return "I can't help with that request." }
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
            !text.isEmpty
        else {
            throw AnthropicVisionError.emptyReply
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Wire types

    private struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let outputConfig: OutputConfig
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model, system, messages
            case maxTokens = "max_tokens"
            case outputConfig = "output_config"
        }
    }

    private struct OutputConfig: Encodable { let effort: String }

    private struct Message: Encodable { let role: String; let content: [ContentPart] }

    private struct ContentPart: Encodable {
        let type: String
        let text: String?
        let source: ImageSource?
    }

    private struct ImageSource: Encodable {
        let type = "base64"
        let mediaType = "image/png"
        let data: String

        enum CodingKeys: String, CodingKey {
            case type, data
            case mediaType = "media_type"
        }
    }

    private struct ResponseBody: Decodable {
        let content: [Block]
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }

        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }

    private struct APIErrorBody: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
}

enum AnthropicVisionError: Error {
    case http(Int, String)
    case emptyReply
}
