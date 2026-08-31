import Foundation

public struct AudioInputDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct AudioDeviceClient: Sendable {
    public var inputDevices: @Sendable () -> [AudioInputDevice]
    public var defaultInputID: @Sendable () -> String?

    public init(
        inputDevices: @escaping @Sendable () -> [AudioInputDevice],
        defaultInputID: @escaping @Sendable () -> String?
    ) {
        self.inputDevices = inputDevices
        self.defaultInputID = defaultInputID
    }

    public static let unavailable = AudioDeviceClient(
        inputDevices: { [] },
        defaultInputID: { nil }
    )
}

public enum MicrophonePreference {
    private static let key = "apace.microphone.selectedUID"

    /// Nil follows the current macOS default, which is also the failover target when a
    /// chosen headset, display, or dock disappears.
    public static var selectedUID: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
