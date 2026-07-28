import ApaceClients
import CoreGraphics
import Foundation
import ImageIO
import os

/// Runs one spoken goal by looping the computer-use protocol: ask Claude for the next
/// action, carry it out, screenshot the result, repeat — until Claude is done or the step
/// cap is hit. Outward/risky goals are confirmed once before anything happens.
struct ComputerUseAgent {
    /// How the model's replies are fetched, injectable so the loop is testable offline.
    typealias Transport = @Sendable (_ messages: [CUMessage], _ width: Int, _ height: Int)
        async throws -> [CUBlock]

    let screen: ScreenCaptureClient
    let control: ComputerControlClient
    let apiKey: String
    /// How long to let the UI settle after an action before the result screenshot —
    /// capturing immediately hands the model a stale frame and derails its next step.
    var settle: Duration = .milliseconds(350)
    var transport: Transport? = nil
    let maxSteps = 15

    private static let log = Logger(subsystem: "so.apace", category: "automation")

    func run(goal: String, handler: AutomationHandler) async {
        if Self.isRisky(goal) {
            guard await handler.confirm("About to: \(goal)") else {
                handler.onStep(.done("Cancelled."))
                return
            }
        }

        handler.onStep(.thinking)

        // The first capture sizes the virtual display for coordinate mapping and gives
        // the model its opening look at the screen, saving a whole screenshot round trip.
        guard let sample = screen.capture(), let (width, height) = Self.imageSize(sample) else {
            handler.onStep(.failed("Couldn't capture the screen — grant Screen Recording."))
            return
        }
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let scaleX = bounds.width / Double(width)
        let scaleY = bounds.height / Double(height)
        let send = transport ?? Self.liveTransport(apiKey: apiKey)

        var messages: [CUMessage] = [
            CUMessage(
                role: "user",
                content: [
                    .text(Self.instructions(goal: goal)),
                    .image(base64: sample.base64EncodedString()),
                ]
            )
        ]

        for _ in 0..<maxSteps {
            if Task.isCancelled {
                handler.onStep(.done("Cancelled."))
                return
            }
            let blocks: [CUBlock]
            do {
                blocks = try await send(messages, width, height)
            } catch is CancellationError {
                handler.onStep(.done("Cancelled."))
                return
            } catch let error as CUError {
                Self.log.error("computer-use request failed: \(error.userMessage, privacy: .public)")
                handler.onStep(.failed(error.userMessage))
                return
            } catch {
                Self.log.error("computer-use request failed: \(error)")
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
                if Task.isCancelled {
                    handler.onStep(.done("Cancelled."))
                    return
                }
                handler.onStep(.acting(Self.describe(input)))
                let image = await perform(input, scaleX: scaleX, scaleY: scaleY)
                results.append(.toolResult(toolUseID: id, imageBase64: image))
            }
            messages.append(CUMessage(role: "user", content: results))
        }

        handler.onStep(.failed("Stopped after \(maxSteps) steps."))
    }

    /// Carries out one action and returns a fresh screenshot (base64 PNG) as its result.
    private func perform(_ input: CUInput, scaleX: Double, scaleY: Double) async -> String? {
        func point(_ coordinate: [Int]) -> CGPoint {
            CGPoint(x: Double(coordinate[0]) * scaleX, y: Double(coordinate[1]) * scaleY)
        }
        switch input.action {
        case "left_click", "double_click", "right_click", "mouse_move":
            if let coordinate = input.coordinate, coordinate.count == 2 {
                let target = point(coordinate)
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
            if let text = input.text {
                if let (code, flags) = Self.parseKey(text) {
                    control.perform(.key(code, flags))
                } else {
                    // Don't silently swallow it — the model believes the key was pressed.
                    Self.log.error("unparseable key action: \(text, privacy: .public)")
                }
            }
        case "scroll":
            // Scroll events land under the pointer, so honour the target coordinate.
            if let coordinate = input.coordinate, coordinate.count == 2 {
                control.perform(.moveMouse(point(coordinate)))
            }
            let step = 40 * max(1, input.scrollAmount ?? 3)
            switch input.scrollDirection {
            case "up": control.perform(.scroll(deltaX: 0, deltaY: step))
            case "down": control.perform(.scroll(deltaX: 0, deltaY: -step))
            case "left": control.perform(.scroll(deltaX: -step, deltaY: 0))
            case "right": control.perform(.scroll(deltaX: step, deltaY: 0))
            default: control.perform(.scroll(deltaX: 0, deltaY: -step))
            }
        case "wait":
            try? await Task.sleep(for: .milliseconds(600))
        default:
            break  // "screenshot" and anything else just return the capture below
        }
        if input.action != "screenshot" {
            try? await Task.sleep(for: settle)
        }
        return screen.capture()?.base64EncodedString()
    }

    // MARK: - Helpers

    static func liveTransport(apiKey: String) -> Transport {
        { messages, width, height in
            try await ComputerUseAPI(apiKey: apiKey, displayWidth: width, displayHeight: height)
                .next(messages)
        }
    }

    /// The opening user message: what the model is doing, how to work, and the goal.
    static func instructions(goal: String) -> String {
        """
        You are operating the user's macOS desktop to carry out one spoken request. \
        The attached screenshot shows the screen as it is right now. Work in small \
        verified steps: prefer keyboard shortcuts and Spotlight (cmd+space) to open \
        apps, take a fresh screenshot when unsure, and finish with a one-line summary \
        of what you did. If the request is ambiguous, impossible, or would need an \
        irreversible step beyond what was asked, stop and say why instead of guessing.

        Request: \(goal)
        """
    }

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
        // Normalize X-keysym spellings the model uses ("Page_Down", "BackSpace").
        guard let name = parts.last?.replacingOccurrences(of: "_", with: ""),
            let code = keyCode(for: name)
        else { return nil }
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
            "delete": 51, "backspace": 51, "forwarddelete": 117,
            "up": 126, "down": 125, "left": 123, "right": 124,
            "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38,
            "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
            "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28,
            "9": 25,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98,
            "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
            "comma": 43, "period": 47, "slash": 44, "semicolon": 41, "quote": 39,
            "minus": 27, "equal": 24, "leftbracket": 33, "rightbracket": 30,
            "backslash": 42, "grave": 50,
        ]
        return map[name].map { CGKeyCode($0) }
    }
}
