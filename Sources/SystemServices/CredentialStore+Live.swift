import ApaceClients
import Foundation
import Security

extension CredentialStore {
    /// Keychain-backed credential storage. Secrets live in the login keychain under the
    /// app's service, never in UserDefaults or on disk in the clear.
    public static let live = CredentialStore(
        save: { value, account in Keychain.save(value, account: account) },
        load: { account in Keychain.load(account: account) },
        delete: { account in Keychain.delete(account: account) }
    )
}

private enum Keychain {
    static let service = "so.apace"

    static func save(_ value: String, account: String) {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
