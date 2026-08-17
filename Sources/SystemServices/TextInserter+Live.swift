import ApaceClients
import AppKit
import ApplicationServices
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
    static func insert(_ text: String) -> TextInsertionResult {
        guard !text.isEmpty else { return .failed }
        guard AXIsProcessTrusted() else { return copyOnly(text) }
        guard !IsSecureEventInputEnabled() else { return copyOnly(text) }
        return paste(text)
    }

    /// Replaces the last `count` inserted characters with `text`: selects them by
    /// holding Shift and pressing Left `count` times, then pastes over the selection.
    /// Selecting (rather than deleting) keeps it to one visible change and lets the app's
    /// own undo treat it as a replace.
    @MainActor
    static func replaceLast(_ count: Int, with text: String) -> TextInsertionResult {
        guard count > 0 else { return .failed }
        guard !IsSecureEventInputEnabled() else { return .failed }
        guard selectBackward(count) else { return .failed }
        return paste(text)
    }

    @MainActor
    private static func selectBackward(_ count: Int) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        let left = CGKeyCode(kVK_LeftArrow)
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: source, virtualKey: left, keyDown: true)
            down?.flags = .maskShift
            down?.post(tap: .cgAnnotatedSessionEventTap)
            let up = CGEvent(keyboardEventSource: source, virtualKey: left, keyDown: false)
            up?.flags = .maskShift
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }
        return true
    }

    @MainActor
    private static func paste(_ text: String) -> TextInsertionResult {
        let pasteboard = NSPasteboard.general
        let previous = PasteboardSnapshot(pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            previous.restore(to: pasteboard)
            return .failed
        }
        let dictationChangeCount = pasteboard.changeCount

        guard postCommandV() else {
            return copyOnly(text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + clipboardRestoreDelay) {
            // Do not overwrite something the user copied while the synthetic paste was
            // in flight. Restore only while our temporary clipboard is still current.
            if pasteboard.changeCount == dictationChangeCount {
                previous.restore(to: pasteboard)
            }
        }
        return .inserted
    }

    @MainActor
    private static func copyOnly(_ text: String) -> TextInsertionResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string) ? .copiedToClipboard : .failed
    }

    /// Posts a ⌘V key-down/up pair into the session event stream.
    private static func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        return keyDown != nil && keyUp != nil
    }
}

/// A type-complete clipboard snapshot. Saving only `.string` destroys copied images,
/// files and rich text, which is especially surprising in a background dictation app.
private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    @MainActor
    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(
                uniqueKeysWithValues: item.types.compactMap { type in
                    item.data(forType: type).map { (type, $0) }
                }
            )
        }
    }

    @MainActor
    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }
}
