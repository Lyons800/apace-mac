@preconcurrency import AVFoundation
import ApaceClients
import ApaceCore
import AppKit
import ApplicationServices
@preconcurrency import Speech

extension PermissionsClient {
    public static let live = PermissionsClient(
        status: { Permissions.status(of: $0) },
        request: { await Permissions.request($0) },
        openSettings: { Permissions.openSettings(for: $0) }
    )
}

private enum Permissions {
    static func status(of permission: Permission) -> PermissionStatus {
        switch permission {
        case .microphone:
            map(AVCaptureDevice.authorizationStatus(for: .audio))
        case .speechRecognition:
            map(SFSpeechRecognizer.authorizationStatus())
        case .accessibility:
            AXIsProcessTrusted() ? .granted : .notDetermined
        }
    }

    static func request(_ permission: Permission) async -> PermissionStatus {
        switch permission {
        case .microphone:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .speechRecognition:
            _ = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        case .accessibility:
            // There's no in-app grant; prompting opens the system dialog that sends
            // the user to Settings. We report back whatever the state is afterwards.
            promptForAccessibility()
        }
        return status(of: permission)
    }

    static func openSettings(for permission: Permission) {
        let anchor: String
        switch permission {
        case .microphone: anchor = "Privacy_Microphone"
        case .speechRecognition: anchor = "Privacy_SpeechRecognition"
        case .accessibility: anchor = "Privacy_Accessibility"
        }
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    private static func promptForAccessibility() {
        // The literal value of `kAXTrustedCheckOptionPrompt`, used directly because the
        // imported global isn't concurrency-safe under Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}
