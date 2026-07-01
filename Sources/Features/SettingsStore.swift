import ApaceClients
import ApaceCore
import Foundation
import Observation

/// The observable store behind the settings window. It surfaces the persisted
/// preferences for the UI to bind to, and writes changes straight back — engine and
/// cleanup toggle through their UserDefaults seams, the API key through the Keychain-
/// backed credential store — so they take effect on the next dictation.
@Observable
public final class SettingsStore {
    public var engine: TranscriptionEngine {
        didSet { EnginePreference.engine = engine }
    }

    public var aiCleanupEnabled: Bool {
        didSet { CleanupPreference.isEnabled = aiCleanupEnabled }
    }

    public var anthropicAPIKey: String {
        didSet { persistAPIKey() }
    }

    private let credentials: CredentialStore

    public init(credentials: CredentialStore) {
        self.credentials = credentials
        engine = EnginePreference.engine
        aiCleanupEnabled = CleanupPreference.isEnabled
        anthropicAPIKey = credentials.load(CredentialStore.anthropicAccount) ?? ""
    }

    private func persistAPIKey() {
        let trimmed = anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            credentials.delete(CredentialStore.anthropicAccount)
        } else {
            credentials.save(trimmed, CredentialStore.anthropicAccount)
        }
    }
}
