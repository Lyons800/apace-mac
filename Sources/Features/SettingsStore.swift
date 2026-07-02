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

    /// The cleanup provider. Changing it reloads the API key for the newly-selected one.
    public var cleanupProvider: CleanupProvider {
        didSet {
            CleanupPreference.provider = cleanupProvider
            apiKey = loadKey(for: cleanupProvider)
        }
    }

    /// The API key for the currently-selected provider; empty for on-device.
    public var apiKey: String {
        didSet { persistKey(apiKey, for: cleanupProvider) }
    }

    private let credentials: CredentialStore

    public init(credentials: CredentialStore) {
        self.credentials = credentials
        engine = EnginePreference.engine
        aiCleanupEnabled = CleanupPreference.isEnabled
        cleanupProvider = CleanupPreference.provider
        apiKey = ""
        apiKey = loadKey(for: cleanupProvider)
    }

    private func loadKey(for provider: CleanupProvider) -> String {
        guard provider.requiresAPIKey else { return "" }
        return credentials.load(provider.keyAccount) ?? ""
    }

    private func persistKey(_ key: String, for provider: CleanupProvider) {
        guard provider.requiresAPIKey else { return }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            credentials.delete(provider.keyAccount)
        } else {
            credentials.save(trimmed, provider.keyAccount)
        }
    }
}
