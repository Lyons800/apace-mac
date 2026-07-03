import ApaceClients
import CoreGraphics
import Foundation
import ImageIO

/// Runs one spoken goal by looping the computer-use protocol: ask Claude for the next
/// action, carry it out, screenshot the result, repeat — until Claude is done or the step
/// cap is hit. Outward/risky goals are confirmed once before anything happens.
struct ComputerUseAgent {
    let screen: ScreenCaptureClient
    let control: ComputerControlClient
    let apiKey: String
    let maxSteps = 15

    func run(goal: String, handler: AutomationHandler) async {
        if Self.isRisky(goal) {
            guard await handler.confirm("About to: \(goal)") else {
                handler.onStep(.done("Cancelled."))
                return
            }
        }

        handler.onStep(.thinking)

        // A first capture just to size the virtual display for coordinate mapping.
        guard let sample = screen.capture(), let (width, height) = Self.imageSize(sample) else {
            handler.onStep(.failed("Couldn't capture the screen — grant Screen Recording."))
            return
        }
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let scale = bounds.width / Double(width)
        let api = ComputerUseAPI(apiKey: apiKey, displayWidth: width, displayHeight: height)

        var messages: [CUMessage] = [CUMessage(role: "user", content: [.text(goal)])]

        for _ in 0..<maxSteps {
            let blocks: [CUBlock]
            do {
                blocks = try await api.next(messages)
            } catch {
                handler.onStep(.failed("Couldn't reach the model."))
                return
            }
            messages.append(CUMessage(role: "assistant", content: blocks))

            let toolUses: [(String, CUInput)] = blocks.compactMap { block in
                if case .toolUse(let id, let input) = block { return (id, input) }
                return nil
            }

            if toolUses.isEmpty {
                let text =
                    blocks
                    .compactMap { if case .text(let t) = $0 { return t } else { return nil } }
                    .joined(separator: " ")
                handler.onStep(.done(text.isEmpty ? "Done." : text))
                return
            }

            var results: [CUBlock] = []
            for (id, input) in toolUses {
                handler.onStep(.acting(Self.describe(input)))
                let image = await perform(input, scale: scale)
                results.append(.toolResult(toolUseID: id, imageBase64: image))
            }
            messages.append(CUMessage(role: "user", content: results))
        }

        handler.onStep(.failed("Stopped after \(maxSteps) steps."))
    }

    /// Carries out one action and returns a fresh screenshot (base64 PNG) as its result.
    private func perform(_ input: CUInput, scale: Double) async -> String? {
        switch input.action {
        case "left_click", "double_click", "right_click", "mouse_move":
            if let point = input.coordinate, point.count == 2 {
                let target = CGPoint(x: Double(point[0]) * scale, y: Double(point[1]) * scale)
                switch input.action {
                case "left_click": control.perform(.click(target))
                case "double_click": control.perform(.doubleClick(target))
                case "right_click": control.perform(.rightClick(target))
                default: control.perform(.moveMouse(target))
                }
            }
        case "type":
            if let text = input.text { control.perform(.type(text)) }
        case "key":
            if let text = input.text, let (code, flags) = Self.parseKey(text) {
                control.perform(.key(code, flags))
            }
        case "scroll":
            control.perform(.scroll(deltaX: 0, deltaY: -40))
        case "wait":
            try? await Task.sleep(for: .milliseconds(600))
        default:
            break  // "screenshot" and anything else just return the capture below
        }
        return screen.capture()?.base64EncodedString()
    }

    // MARK: - Helpers

    private static let riskyVerbs = [
        "send", "message", "reply", "text", "email", "post", "tweet", "dm", "share",
        "publish", "delete", "remove", "trash", "buy", "purchase", "pay", "order", "book",
    ]

    static func isRisky(_ goal: String) -> Bool {
        let lowered = goal.lowercased()
        return riskyVerbs.contains { lowered.contains($0) }
    }

    static func describe(_ input: CUInput) -> String {
        switch input.action {
        case "screenshot": "Looking at the screen…"
        case "left_click", "double_click", "right_click": "Clicking…"
        case "mouse_move": "Moving the pointer…"
        case "type": "Typing “\(input.text ?? "")”…"
        case "key": "Pressing \(input.text ?? "a key")…"
        case "scroll": "Scrolling…"
        default: "Working…"
        }
    }

    static func imageSize(_ data: Data) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    static func parseKey(_ string: String) -> (CGKeyCode, CGEventFlags)? {
        let parts = string.lowercased().split(separator: "+").map(String.init)
        guard let name = parts.last, let code = keyCode(for: name) else { return nil }
        var flags: CGEventFlags = []
        for modifier in parts.dropLast() {
            switch modifier {
            case "cmd", "command", "super": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "ctrl", "control": flags.insert(.maskControl)
            case "alt", "option": flags.insert(.maskAlternate)
            default: break
            }
        }
        return (code, flags)
    }

    private static func keyCode(for name: String) -> CGKeyCode? {
        let map: [String: Int] = [
            "return": 36, "enter": 36, "escape": 53, "esc": 53, "tab": 48, "space": 49,
            "delete": 51, "backspace": 51, "up": 126, "down": 125, "left": 123, "right": 124,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38,
            "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
            "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
        ]
        return map[name].map { CGKeyCode($0) }
    }
}
