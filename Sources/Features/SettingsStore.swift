import ApaceClients
import ApaceCore
import Observation

/// The observable store behind the settings window. It surfaces the persisted
/// preferences for the UI to bind to, and writes changes straight back through
/// ``EnginePreference`` so they take effect on the next dictation.
@Observable
public final class SettingsStore {
    public var engine: TranscriptionEngine {
        didSet { EnginePreference.engine = engine }
    }

    public var aiCleanupEnabled: Bool {
        didSet { CleanupPreference.isEnabled = aiCleanupEnabled }
    }

    public init() {
        engine = EnginePreference.engine
        aiCleanupEnabled = CleanupPreference.isEnabled
    }
}
