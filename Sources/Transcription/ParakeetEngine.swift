@preconcurrency import FluidAudio
import Foundation

/// NVIDIA Parakeet TDT v3 via FluidAudio — fast, accurate on-device transcription that
/// takes the whole 16 kHz mono buffer at once, so pauses in a dictation don't split or
/// reset it. The model downloads on first use and is cached; the shared instance keeps
/// it loaded for the app's lifetime.
actor ParakeetEngine {
    static let shared = ParakeetEngine()

    private let version: AsrModelVersion = .v3
    private var manager: AsrManager?
    private var loadTask: Task<AsrManager, Error>?

    /// Transcribes 16 kHz mono float PCM, loading the model on first call.
    func transcribe(_ samples: [Float]) async throws -> String {
        let manager = try await ready()
        var state = try TdtDecoderState(decoderLayers: version.decoderLayers)
        let result = try await manager.transcribe(
            samples,
            decoderState: &state,
            language: Language(rawValue: "en")
        )
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Kicks off model loading without transcribing, so the first dictation is instant.
    func preload() {
        Task { _ = try? await ready() }
    }

    private func ready() async throws -> AsrManager {
        if let manager { return manager }
        if let loadTask { return try await loadTask.value }

        let version = version
        let task = Task { () async throws -> AsrManager in
            let models = try await AsrModels.downloadAndLoad(version: version)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            return manager
        }
        loadTask = task

        do {
            let manager = try await task.value
            self.manager = manager
            self.loadTask = nil
            return manager
        } catch {
            loadTask = nil
            throw error
        }
    }
}
