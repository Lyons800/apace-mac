import ApaceClients
import ApaceCore
import Foundation

/// Replays a failed history item without asking the user to dictate it again. If text
/// was already recognised, retry only attempts insertion; otherwise it re-transcribes
/// the locally retained recovery audio and then inserts the processed result.
public actor DictationRecoveryController {
    private let clients: DictationClients

    public init(clients: DictationClients) {
        self.clients = clients
    }

    @discardableResult
    public func retry(_ id: UUID) async -> Bool {
        guard let entry = TranscriptHistory.entry(id: id) else { return false }

        if !entry.text.isEmpty {
            return await insert(entry.text, id: id)
        }

        guard entry.hasAudio, let samples = TranscriptHistory.audioSamples(id: id) else {
            TranscriptHistory.update(
                id: id,
                status: .failed,
                errorMessage: "Recovery audio is no longer available."
            )
            return false
        }

        TranscriptHistory.update(id: id, status: .processing, errorMessage: nil)
        do {
            let raw = try await clients.transcriber.transcribe(samples)
            let quick = clients.processor.quick(raw)
            guard !quick.isEmpty else {
                TranscriptHistory.update(
                    id: id,
                    rawText: raw,
                    status: .failed,
                    errorMessage: DictationController.noSpeechRecognizedMessage
                )
                return false
            }
            let processed = await clients.processor.process(raw)
            let result = processed.isEmpty ? quick : processed
            TranscriptHistory.update(
                id: id,
                rawText: raw,
                text: result,
                status: .processing,
                discardAudio: true
            )
            return await insert(result, id: id)
        } catch {
            TranscriptHistory.update(
                id: id,
                status: .failed,
                errorMessage: DictationController.transcriptionErrorMessage
            )
            return false
        }
    }

    private func insert(_ text: String, id: UUID) async -> Bool {
        switch await clients.inserter.insert(text) {
        case .inserted:
            TranscriptHistory.update(id: id, status: .inserted, errorMessage: nil)
            return true
        case .copiedToClipboard:
            TranscriptHistory.update(
                id: id,
                status: .copiedToClipboard,
                errorMessage: DictationController.copiedToClipboardMessage
            )
            return false
        case .failed:
            TranscriptHistory.update(
                id: id,
                status: .failed,
                errorMessage: DictationController.insertionErrorMessage
            )
            return false
        }
    }
}
