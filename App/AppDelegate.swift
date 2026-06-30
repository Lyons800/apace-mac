import AppKit
import Features

/// Owns the app's single ``DictationModel`` and brings it to life once the app has
/// finished launching. Keeping this in the delegate (rather than a `@State` on the
/// `App`) gives the model a stable lifetime independent of SwiftUI re-evaluating the
/// scene.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let dictation = DictationModel(clients: .live)

    func applicationDidFinishLaunching(_ notification: Notification) {
        dictation.activate()
    }
}
