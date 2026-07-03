import Foundation

/// A minimal client for Anthropic's computer-use tool. It sends the running message
/// history and returns the assistant's reply blocks; the agent executes any actions and
/// feeds screenshots back as tool results. Model / tool version / beta header match the
/// current (2025-11-24) computer-use branch, which Claude Sonnet 5 and Opus 4.7+ use.
struct ComputerUseAPI {
    var apiKey: String
    var displayWidth: Int
    var displayHeight: Int

    var model = "claude-sonnet-5"
    private let endpoint = "https://api.anthropic.com/v1/messages"
    private let toolVersion = "computer_20251124"
    private let beta = "computer-use-2025-11-24"

    func next(_ messages: [CUMessage]) async throws -> [CUBlock] {
        guard let url = URL(string: endpoint) else { throw CUError.badResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(beta, forHTTPHeaderField: "anthropic-beta")

        let body = RequestBody(
            model: model,
            maxTokens: 1024,
            tools: [
                Tool(
                    type: toolVersion,
                    name: "computer",
                    displayWidthPx: displayWidth,
                    displayHeightPx: displayHeight
                )
            ],
            messages: messages
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CUError.badResponse }
        return try JSONDecoder().decode(ResponseBody.self, from: data).content
    }

    private struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let tools: [Tool]
        let messages: [CUMessage]

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case tools
            case messages
        }
    }

    private struct Tool: Encodable {
        let type: String
        let name: String
        let displayWidthPx: Int
        let displayHeightPx: Int

        enum CodingKeys: String, CodingKey {
            case type
            case name
            case displayWidthPx = "display_width_px"
            case displayHeightPx = "display_height_px"
        }
    }

    private struct ResponseBody: Decodable {
        let content: [CUBlock]
    }
}

enum CUError: Error {
    case badResponse
}

/// One message in the computer-use conversation.
struct CUMessage: Codable {
    let role: String
    let content: [CUBlock]
}

/// A content block. We send text and tool results, and receive text and tool uses; all
/// four are (de)coded by their `type` tag.
enum CUBlock: Codable {
    case text(String)
    case toolUse(id: String, input: CUInput)
    case toolResult(toolUseID: String, imageBase64: String?)

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
        case toolUseID = "tool_use_id"
        case content, source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "tool_use":
            self = .toolUse(
                id: try container.decode(String.self, forKey: .id),
                input: try container.decode(CUInput.self, forKey: .input)
            )
        default:
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode("computer", forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseID, let imageBase64):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseID, forKey: .toolUseID)
            var content = container.nestedUnkeyedContainer(forKey: .content)
            if let imageBase64 {
                try content.encode(ImageContent(base64: imageBase64))
            } else {
                try content.encode(TextContent(text: "action performed"))
            }
        }
    }

    private struct TextContent: Encodable {
        let type = "text"
        let text: String
    }

    private struct ImageContent: Encodable {
        let type = "image"
        let source: Source

        init(base64: String) { source = Source(data: base64) }

        struct Source: Encodable {
            let type = "base64"
            let mediaType = "image/png"
            let data: String

            enum CodingKeys: String, CodingKey {
                case type
                case mediaType = "media_type"
                case data
            }
        }
    }
}

/// The input Claude sends for a `computer` tool use.
struct CUInput: Codable {
    let action: String
    let coordinate: [Int]?
    let text: String?
    let scrollDirection: String?
    let scrollAmount: Int?

    init(
        action: String,
        coordinate: [Int]? = nil,
        text: String? = nil,
        scrollDirection: String? = nil,
        scrollAmount: Int? = nil
    ) {
        self.action = action
        self.coordinate = coordinate
        self.text = text
        self.scrollDirection = scrollDirection
        self.scrollAmount = scrollAmount
    }

    enum CodingKeys: String, CodingKey {
        case action, coordinate, text
        case scrollDirection = "scroll_direction"
        case scrollAmount = "scroll_amount"
    }
}
