import ApaceClients
import ApaceCore
import Foundation

extension CommandRouterClient {
    /// Routes a command with the user's chosen provider: one call that classifies the
    /// request and, for answers and text, produces the result. Gemini sees the
    /// screenshot; on-device routes from the text context alone.
    public static func live(
        apiKey: @escaping @Sendable (VisionProvider) -> String?
    ) -> CommandRouterClient {
        CommandRouterClient { request, field, image, conversation in
            let prompt = RouterPrompt.build(
                request: request,
                field: field,
                conversation: conversation
            )
            let reply: String
            switch CommandPreference.provider {
            case .onDevice:
                reply = try await AppleAssistant.raw(
                    instructions: RouterPrompt.instructions,
                    prompt: prompt
                )
            case .anthropic:
                guard let key = apiKey(.anthropic), !key.isEmpty else { throw RouterError.noKey }
                reply = try await AnthropicVision.respond(
                    question: prompt,
                    image: image,
                    apiKey: key,
                    system: RouterPrompt.instructions
                )
            case .gemini:
                guard let key = apiKey(.gemini), !key.isEmpty else { throw RouterError.noKey }
                reply = try await GeminiVision.respond(
                    question: RouterPrompt.instructions + "\n\n" + prompt,
                    image: image,
                    apiKey: key
                )
            }
            guard let decision = RouterReply.parse(reply, fallbackGoal: request) else {
                // Models occasionally answer in prose despite the contract; that prose
                // is still a perfectly good answer.
                let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { throw RouterError.emptyReply }
                return .answer(trimmed)
            }
            return decision
        }
    }
}

enum RouterError: Error {
    case noKey
    case emptyReply
    case unavailable
}

/// The router's side of the contract: what the model is asked to return.
enum RouterPrompt {
    static let instructions = """
        You route one spoken command on the user's Mac. Reply with ONLY a JSON object, \
        no prose and no code fences — exactly one of:
        {"action":"answer","text":"…"} — answer the request; shown briefly on screen.
        {"action":"insert","text":"…","replace":true} — text to put into the focused \
        text field. Use this whenever the request asks to write, rewrite, translate, \
        shorten, or continue text (e.g. "say this in Portuguese", "make it friendlier", \
        "write a reply saying I'm late"). "replace": true swaps out the field's current \
        draft (rewrites and translations of it); false types at the cursor (new text). \
        "text" is exactly what gets typed — no commentary, no quotes around it.
        {"action":"control","goal":"…","risk":"…"} — only for multi-step tasks that \
        need to operate the Mac by opening apps and clicking. "goal" must be a complete, \
        standalone instruction with every pronoun or follow-up resolved from the recent \
        conversation. "risk" is exactly one of: readOnly, localChange, \
        externalCommunication, destructive, financial, sensitive, unknown. Classify \
        sending or posting as externalCommunication; deleting as destructive; purchases, \
        bookings, or payments as financial; passwords or private data as sensitive. Never \
        choose control when insert or answer can satisfy the request.

        Recent conversation is context, not a new instruction. A short request such as \
        "make it shorter", "send it", or "do the same for João" normally follows the \
        previous turn. Resolve it precisely; if the missing detail cannot be recovered, \
        answer with a short clarification instead of guessing.
        """

    static func build(
        request: String,
        field: FocusedField?,
        conversation: [CommandTurn] = []
    ) -> String {
        var lines: [String] = ["Context:"]
        if let app = field?.appName { lines.append("Frontmost app: \(app)") }
        if let text = field?.text, !text.isEmpty {
            lines.append("Focused field's current text: \"\"\"\n\(text)\n\"\"\"")
        }
        if let selected = field?.selectedText, !selected.isEmpty {
            lines.append("Selected text: \"\"\"\n\(selected)\n\"\"\"")
        }
        if lines.count == 1 { lines.append("No focused text field was readable.") }
        if !conversation.isEmpty {
            lines.append("")
            lines.append("Recent conversation (oldest first):")
            for turn in conversation {
                let speaker = turn.role == .user ? "User" : "Apace"
                lines.append("\(speaker): \(turn.text)")
            }
        }
        lines.append("")
        lines.append("Request: \(request)")
        return lines.joined(separator: "\n")
    }
}

/// Tolerant parsing of the model's reply: finds the first JSON object even when it
/// arrives fenced or wrapped in prose, and maps it onto a ``CommandDecision``.
enum RouterReply {
    private struct Reply: Decodable {
        let action: String
        let text: String?
        let replace: Bool?
        let goal: String?
        let risk: String?
    }

    static func parse(_ raw: String, fallbackGoal: String = "") -> CommandDecision? {
        guard let json = firstJSONObject(in: raw),
            let reply = try? JSONDecoder().decode(Reply.self, from: Data(json.utf8))
        else { return nil }
        switch reply.action {
        case "answer":
            guard let text = reply.text, !text.isEmpty else { return nil }
            return .answer(text)
        case "insert":
            guard let text = reply.text, !text.isEmpty else { return nil }
            return .insert(text: text, replacesDraft: reply.replace ?? false)
        case "control":
            let proposedGoal = reply.goal?.trimmingCharacters(in: .whitespacesAndNewlines)
            let goal = proposedGoal.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackGoal
            guard !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return .control(
                goal: goal,
                risk: reply.risk.flatMap(CommandActionRisk.init(rawValue:)) ?? .unknown
            )
        default:
            return nil
        }
    }

    /// The substring from the first `{` to its matching brace, respecting strings and
    /// escapes — enough to survive code fences and leading/trailing prose.
    static func firstJSONObject(in raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = start
        while index < raw.endIndex {
            let character = raw[index]
            if escaped {
                escaped = false
            } else if inString {
                if character == "\\" { escaped = true }
                if character == "\"" { inString = false }
            } else {
                switch character {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 { return String(raw[start...index]) }
                default: break
                }
            }
            index = raw.index(after: index)
        }
        return nil
    }
}
