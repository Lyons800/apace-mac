@preconcurrency import AVFoundation
import ApaceClients
import ApaceCore
@preconcurrency import FluidAudio
import Foundation

/// NVIDIA Parakeet TDT via FluidAudio. Ordinary dictation uses its accurate batch
/// path. When the user has taught Apace names or terms, the same model runs through
/// FluidAudio's CTC-backed custom-vocabulary path so candidates are accepted only
/// when both the spelling hint and the audio support them.
actor ParakeetEngine {
    /// v3 is multilingual (25 languages); v2 is English-only with the best English WER.
    static let v3 = ParakeetEngine(version: .v3)
    static let v2 = ParakeetEngine(version: .v2)

    private let version: AsrModelVersion
    private var models: AsrModels?
    private var modelLoadTask: Task<AsrModels, Error>?
    private var batchManager: AsrManager?
    private var ctcModels: CtcModels?
    private var ctcLoadTask: Task<CtcModels, Error>?

    init(version: AsrModelVersion) {
        self.version = version
    }

    /// Transcribes 16 kHz mono float PCM, loading the model on first call.
    func transcribe(_ samples: [Float]) async throws -> String {
        try await transcribe(samples, vocabulary: VocabularyPreference.vocabulary)
    }

    /// An explicit vocabulary seam used by pronunciation learning to ask what the
    /// recogniser hears before any taught-name context is applied.
    func transcribe(_ samples: [Float], vocabulary: Vocabulary) async throws -> String {
        if !vocabulary.activeEntries.isEmpty,
            let biased = try? await transcribe(samples, with: vocabulary)
        {
            return biased
        }

        return try await transcribeBatch(samples)
    }

    /// Kicks off model loading without transcribing, so the first dictation is instant.
    func preload() {
        Task {
            _ = try? await readyBatchManager()
            if !VocabularyPreference.vocabulary.activeEntries.isEmpty {
                _ = try? await readyCtcModels()
            }
        }
    }

    /// Awaits every model needed by the current vocabulary configuration.
    func prepare() async {
        _ = try? await readyBatchManager()
        if !VocabularyPreference.vocabulary.activeEntries.isEmpty {
            _ = try? await readyCtcModels()
        }
    }

    private func transcribeBatch(_ samples: [Float]) async throws -> String {
        let manager = try await readyBatchManager()
        var state = try TdtDecoderState(decoderLayers: version.decoderLayers)
        let result = try await manager.transcribe(
            samples,
            decoderState: &state,
            language: Language(rawValue: "en")
        )
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func transcribe(_ samples: [Float], with vocabulary: Vocabulary) async throws -> String
    {
        guard let buffer = Self.makeBuffer(from: samples) else {
            throw TranscriptionError.audioBufferUnavailable
        }

        let ctcModels = try await readyCtcModels()
        let tokenizer = try await CtcTokenizer.load(
            from: CtcModels.defaultCacheDirectory(for: ctcModels.variant)
        )
        let terms = vocabulary.activeEntries.map { entry in
            CustomVocabularyTerm(
                text: entry.term,
                aliases: entry.aliases.isEmpty ? nil : entry.aliases,
                ctcTokenIds: tokenizer.encode(entry.term),
                minSimilarity: 0.8
            )
        }
        let context = CustomVocabularyContext(terms: terms)
        let models = try await readyModels()

        // Confirmation is immediate because Apace supplies a complete captured utterance,
        // not an open-ended live stream. This ensures short names are acoustically rescored.
        let config = SlidingWindowAsrConfig(
            chunkSeconds: 11,
            hypothesisChunkSeconds: 2,
            leftContextSeconds: 2,
            rightContextSeconds: 2,
            minContextForConfirmation: 0,
            confirmationThreshold: 0,
            tdtConfig: TdtConfig(blankId: version.blankId)
        )
        let manager = SlidingWindowAsrManager(config: config)
        try await manager.loadModels(models)
        try await manager.configureVocabularyBoosting(
            vocabulary: context,
            ctcModels: ctcModels
        )
        try await manager.startStreaming(source: .microphone)
        await manager.streamAudio(buffer)
        return try await manager.finish().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readyBatchManager() async throws -> AsrManager {
        if let batchManager { return batchManager }
        let models = try await readyModels()
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        batchManager = manager
        return manager
    }

    private func readyModels() async throws -> AsrModels {
        if let models { return models }
        if let modelLoadTask { return try await modelLoadTask.value }

        let version = version
        let task = Task { try await AsrModels.downloadAndLoad(version: version) }
        modelLoadTask = task
        do {
            let loaded = try await task.value
            models = loaded
            modelLoadTask = nil
            return loaded
        } catch {
            modelLoadTask = nil
            throw error
        }
    }

    private func readyCtcModels() async throws -> CtcModels {
        if let ctcModels { return ctcModels }
        if let ctcLoadTask { return try await ctcLoadTask.value }

        let task = Task { try await CtcModels.downloadAndLoad(variant: .ctc110m) }
        ctcLoadTask = task
        do {
            let loaded = try await task.value
            ctcModels = loaded
            ctcLoadTask = nil
            return loaded
        } catch {
            ctcLoadTask = nil
            throw error
        }
    }

    private static func makeBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard
            !samples.isEmpty,
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            ),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(samples.count)
            ),
            let channel = buffer.floatChannelData?.pointee
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
                channel.update(from: base, count: samples.count)
            }
        }
        return buffer
    }
}
