import Foundation
import HuggingFace
import MLXLMCommon
import Tokenizers

/// Bridges Hugging Face's downloader and tokenizer to MLXLMCommon without relying on
/// an Xcode macro plug-in. Keeping these adapters explicit lets CI and fresh installs
/// build without requiring a manual "Enable Macro" approval in Xcode.
struct HuggingFaceDownloader: MLXLMCommon.Downloader {
    private let client = HuggingFace.HubClient()

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest _: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repository = HuggingFace.Repo.ID(rawValue: id) else {
            throw HuggingFaceAdapterError.invalidRepositoryID(id)
        }

        return try await client.downloadSnapshot(
            of: repository,
            revision: revision ?? "main",
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }
}

struct HuggingFaceTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return HuggingFaceTokenizer(tokenizer)
    }
}

private struct HuggingFaceTokenizer: MLXLMCommon.Tokenizer {
    private let tokenizer: any Tokenizers.Tokenizer

    init(_ tokenizer: any Tokenizers.Tokenizer) {
        self.tokenizer = tokenizer
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        tokenizer.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        tokenizer.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        tokenizer.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        tokenizer.convertIdToToken(id)
    }

    var bosToken: String? { tokenizer.bosToken }
    var eosToken: String? { tokenizer.eosToken }
    var unknownToken: String? { tokenizer.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try tokenizer.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

private enum HuggingFaceAdapterError: LocalizedError {
    case invalidRepositoryID(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryID(let id):
            "Invalid Hugging Face repository ID: \(id)"
        }
    }
}
