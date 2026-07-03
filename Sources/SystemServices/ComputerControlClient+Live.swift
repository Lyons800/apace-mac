import ApaceClients
import CoreGraphics
import Foundation

extension ComputerControlClient {
    /// Posts real input events via `CGEvent`. Requires Accessibility permission — the
    /// same grant the hotkey uses — or the OS silently drops the events.
    public static let live = ComputerControlClient { action in
        let source = CGEventSource(stateID: .combinedSessionState)
        switch action {
        case .moveMouse(let point):
            mouse(source, .mouseMoved, point, .left)
        case .click(let point):
            mouse(source, .leftMouseDown, point, .left)
            mouse(source, .leftMouseUp, point, .left)
        case .doubleClick(let point):
            doubleClick(source, point)
        case .rightClick(let point):
            mouse(source, .rightMouseDown, point, .right)
            mouse(source, .rightMouseUp, point, .right)
        case .type(let text):
            type(source, text)
        case .key(let code, let flags):
            key(source, code, flags)
        case .scroll(let deltaX, let deltaY):
            let event = CGEvent(
                scrollWheelEvent2Source: source,
                units: .pixel,
                wheelCount: 2,
                wheel1: Int32(deltaY),
                wheel2: Int32(deltaX),
                wheel3: 0
            )
            event?.post(tap: .cghidEventTap)
        }
    }

    private static func mouse(
        _ source: CGEventSource?,
        _ type: CGEventType,
        _ point: CGPoint,
        _ button: CGMouseButton
    ) {
        CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        )?
        .post(tap: .cghidEventTap)
    }

    private static func doubleClick(_ source: CGEventSource?, _ point: CGPoint) {
        for _ in 0..<2 {
            mouse(source, .leftMouseDown, point, .left)
            mouse(source, .leftMouseUp, point, .left)
        }
        // Tag the second down/up as click-count 2 so apps register a real double-click.
        let down = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        down?.setIntegerValueField(.mouseEventClickState, value: 2)
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        up?.setIntegerValueField(.mouseEventClickState, value: 2)
        up?.post(tap: .cghidEventTap)
    }

    private static func key(_ source: CGEventSource?, _ code: CGKeyCode, _ flags: CGEventFlags) {
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    private static func type(_ source: CGEventSource?, _ text: String) {
        for chunk in text.chunked(by: 20) {
            var utf16 = Array(chunk.utf16)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            up?.post(tap: .cghidEventTap)
        }
    }
}

extension String {
    /// Splits into fixed-size pieces so a long `type` doesn't exceed the event's buffer.
    fileprivate func chunked(by size: Int) -> [String] {
        guard count > size else { return [self] }
        var pieces: [String] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            pieces.append(String(self[index..<end]))
            index = end
        }
        return pieces
    }
}
