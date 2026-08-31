import ApaceCore
import Foundation

/// Remembers that macOS has already been asked for a permission. The Accessibility
/// and Input Monitoring APIs only expose a yes/no preflight, so a false result cannot
/// distinguish "never asked" from "not granted" without this durable marker.
public enum PermissionRequestPreference {
    private static let key = "apace.permissions.requested"

    public static var requested: Set<Permission> {
        let values = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(values.compactMap(Permission.init(rawValue:)))
    }

    public static func mark(_ permission: Permission) {
        var updated = requested
        updated.insert(permission)
        UserDefaults.standard.set(updated.map(\.rawValue).sorted(), forKey: key)
    }
}
