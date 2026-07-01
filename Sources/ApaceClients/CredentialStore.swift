/// The port for storing secrets (API keys) securely. The live adapter is backed by
/// the macOS Keychain; the settings UI writes through it and the cleanup adapter reads
/// from it. Kept a struct of closures so nothing in the domain imports Security.
public struct CredentialStore: Sendable {
    public var save: @Sendable (_ value: String, _ account: String) -> Void
    public var load: @Sendable (_ account: String) -> String?
    public var delete: @Sendable (_ account: String) -> Void

    public init(
        save: @escaping @Sendable (String, String) -> Void,
        load: @escaping @Sendable (String) -> String?,
        delete: @escaping @Sendable (String) -> Void
    ) {
        self.save = save
        self.load = load
        self.delete = delete
    }

    /// Keychain account name for the user's Anthropic API key (BYO cleanup).
    public static let anthropicAccount = "anthropic-api-key"
}
