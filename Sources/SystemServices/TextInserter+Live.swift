import ApaceClients
import AppKit
import Carbon.HIToolbox
import CoreGraphics

extension TextInserterClient {
    /// Inserts text into the frontmost application.
    ///
    /// The primary path is the pasteboard plus a synthetic ⌘V: it is the only method
    /// that works reliably across native, Electron, and web text fields, and it
    /// preserves the app's own undo. We stash and restore the user's clipboard around
    /// the paste so dictation doesn't clobber what they had copied.
    ///
    /// Secure Event Input (password fields, some terminals) blocks synthetic events
    /// entirely, so we detect it and decline rather than silently dropping characters.
    public static let live = TextInserterClient(
        insert: { text in
            await MainActor.run { TextInserter.insert(text) }
        },
        replaceLast: { deleteCount, text in
            await MainActor.run { TextInserter.replaceLast(deleteCount, with: text) }
        }
    )
}

/// The concrete insertion mechanics, kept off the `TextInserterClient` value so the
/// port stays a plain struct of closures.
private enum TextInserter {
    /// How long to wait before restoring the previous clipboard — long enough for the
    /// synthetic paste to be read by the frontmost app, short enough to feel instant.
    private static let clipboardRestoreDelay: TimeInterval = 0.15

    @MainActor
    static func insert(_ text: String) {
        guard !text.isEmpty else { return }
        guard !IsSecureEventInputEnabled() else { return }
        paste(text)
    }

    /// Replaces the last `count` inserted characters with `text`: selects them by
    /// holding Shift and pressing Left `count` times, then pastes over the selection.
    /// Selecting (rather than deleting) keeps it to one visible change and lets the app's
    /// own undo treat it as a replace.
    @MainActor
    static func replaceLast(_ count: Int, with text: String) {
        guard count > 0 else { return }
        guard !IsSecureEventInputEnabled() else { return }
        selectBackward(count)
        paste(text)
    }

    @MainActor
    private static func selectBackward(_ count: Int) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let left = CGKeyCode(kVK_LeftArrow)
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: source, virtualKey: left, keyDown: true)
            down?.flags = .maskShift
            down?.post(tap: .cgAnnotatedSessionEventTap)
            let up = CGEvent(keyboardEventSource: source, virtualKey: left, keyDown: false)
            up?.flags = .maskShift
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    @MainActor
    private static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + clipboardRestoreDelay) {
            pasteboard.clearContents()
            if let previous {
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    /// Posts a ⌘V key-down/up pair into the session event stream.
    private static func postCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
