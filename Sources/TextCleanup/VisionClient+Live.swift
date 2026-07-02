import ApaceClients
import ApaceCore
import FoundationModels

extension VisionClient {
    /// Routes a command to the user's chosen provider. On-device answers with Apple
    /// Intelligence (text only for now — on-device image input lands with the macOS 26
    /// Foundation Models image API); Gemini answers with the screenshot attached.
    public static func live(apiKey: @escaping @Sendable (VisionProvider) -> String?) -> VisionClient
    {
        VisionClient { question, image in
            switch CommandPreference.provider {
            case .onDevice:
                return await AppleAssistant.answer(question)
            case .gemini:
                guard let key = apiKey(.gemini), !key.isEmpty else {
                    return
                        "Add a Google Gemini API key in Command settings to answer with the screen."
                }
                return try await GeminiVision.respond(question: question, image: image, apiKey: key)
            }
        }
    }
}

/// A concise on-device answer via Apple Intelligence (macOS 26+).
enum AppleAssistant {
    static func answer(_ question: String) async -> String {
        guard #available(macOS 26.0, *) else {
            return "On-device answers need Apple Intelligence (macOS 26)."
        }
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return "Turn on Apple Intelligence, or switch Command mode to Cloud."
        }
        let session = LanguageModelSession(
            instructions:
                "You are a concise voice assistant. Answer the request directly and briefly."
        )
        do {
            return try await session.respond(to: question).content
        } catch {
            return "Sorry — I couldn't answer that just now."
        }
    }
}
