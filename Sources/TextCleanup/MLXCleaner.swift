import Foundation
import MLXLLM
import MLXLMCommon

/// On-device cleanup via a small local LLM (MLX) — the privacy default for Macs without
/// Apple Intelligence. Loads Qwen2.5-1.5B-Instruct (4-bit) once and keeps it resident;
/// the model downloads from Hugging Face on first use (~0.9 GB). Generation is
/// deterministic so it edits rather than rewrites, and any failure returns the text
/// untouched.
actor MLXCleaner {
    static let shared = MLXCleaner()

    private let configuration = ModelConfiguration(id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit")
    private var container: ModelContainer?
    private var loadTask: Task<ModelContainer, Error>?

    func clean(_ text: String) async -> String {
        guard let container = try? await ready() else { return text }

        var parameters = GenerateParameters()
        parameters.temperature = 0
        let session = ChatSession(
            container,
            instructions: CleanupInstructions.system,
            generateParameters: parameters
        )

        guard let cleaned = try? await session.respond(to: text) else { return text }
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? text : trimmed
    }

    /// Kicks off the download/load in the background so the first cleanup is instant.
    func preload() {
        Task { _ = try? await ready() }
    }

    private func ready() async throws -> ModelContainer {
        if let container { return container }
        if let loadTask { return try await loadTask.value }

        let configuration = configuration
        let task = Task { try await loadModelContainer(configuration: configuration) }
        loadTask = task

        do {
            let container = try await task.value
            self.container = container
            self.loadTask = nil
            return container
        } catch {
            loadTask = nil
            throw error
        }
    }
}
