import Foundation
@preconcurrency import WhisperKit

/// OpenAI Whisper via Core ML (WhisperKit) — the broad-language option. Like Parakeet
/// it transcribes the whole buffer at once (no silence endpointing), so long dictations
/// with pauses come through intact. Downloads the model on first use and keeps it
/// loaded on the shared instance.
actor WhisperKitEngine {
    /// Turbo: near-large-v3 accuracy at several times the speed (~632 MB). Full large-v3:
    /// maximum accuracy, slower and larger (~947 MB).
    static let turbo = WhisperKitEngine(model: "openai_whisper-large-v3-v20240930_turbo")
    static let largeV3 = WhisperKitEngine(model: "openai_whisper-large-v3")

    private let model: String
    private var kit: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    init(model: String) {
        self.model = model
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        let kit = try await ready()
        let options = DecodingOptions(language: "en", temperature: 0.0)
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        return results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func preload() {
        Task { _ = try? await ready() }
    }

    /// Awaits the model being loaded — used to drive the "preparing model" indicator.
    func prepare() async {
        _ = try? await ready()
    }

    private func ready() async throws -> WhisperKit {
        if let kit { return kit }
        if let loadTask { return try await loadTask.value }

        let model = model
        let task = Task { () async throws -> WhisperKit in
            let config = WhisperKitConfig(
                model: model,
                downloadBase: Self.modelDirectory,
                prewarm: false,
                load: true,
                download: true
            )
            return try await WhisperKit(config)
        }
        loadTask = task

        do {
            let kit = try await task.value
            self.kit = kit
            self.loadTask = nil
            return kit
        } catch {
            loadTask = nil
            throw error
        }
    }

    /// A writable cache for the downloaded Core ML models.
    private static let modelDirectory: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Apace/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()
}
