import ApaceClients
import ApaceCore
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import Automation

/// A tiny real PNG so `imageSize` and the base64 plumbing run against genuine data.
private func makePNG(width: Int = 4, height: Int = 4) -> Data {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let image = context.makeImage()!
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    )!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}

/// Records what the agent did, safely across the concurrent hops.
private final class LoopRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _actions: [String] = []
    private var _requests: [[CUMessage]] = []
    private var _steps: [AutomationStep] = []

    var actions: [String] { lock.withLock { _actions } }
    var requests: [[CUMessage]] { lock.withLock { _requests } }
    var steps: [AutomationStep] { lock.withLock { _steps } }

    func record(action: String) { lock.withLock { _actions.append(action) } }
    func record(request: [CUMessage]) { lock.withLock { _requests.append(request) } }
    func record(step: AutomationStep) { lock.withLock { _steps.append(step) } }
}

private func makeAgent(
    recorder: LoopRecorder,
    replies: [[CUBlock]]
) -> ComputerUseAgent {
    let counter = LockedCounter()
    return ComputerUseAgent(
        screen: ScreenCaptureClient(capture: { makePNG() }),
        control: ComputerControlClient(perform: { action in
            recorder.record(action: label(for: action))
        }),
        apiKey: "test-key",
        settle: .zero,
        transport: { messages, _, _ in
            recorder.record(request: messages)
            let index = counter.next()
            return index < replies.count ? replies[index] : [.text("fallback")]
        }
    )
}

private func label(for action: ControlAction) -> String {
    switch action {
    case .moveMouse: "moveMouse"
    case .click: "click"
    case .doubleClick: "doubleClick"
    case .rightClick: "rightClick"
    case .type(let text): "type:\(text)"
    case .key: "key"
    case .scroll: "scroll"
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int {
        lock.withLock {
            defer { value += 1 }; return value
        }
    }
}

private func makeHandler(_ recorder: LoopRecorder) -> AutomationHandler {
    AutomationHandler(onStep: { recorder.record(step: $0) }, confirm: { _ in true })
}

private func request(
    _ goal: String,
    risk: CommandActionRisk = .readOnly,
    approved: Bool = false
) -> AutomationRequest {
    AutomationRequest(goal: goal, risk: risk, userApproved: approved)
}

@Suite("Computer-use loop")
struct ComputerUseLoopTests {
    @Test("The first request carries the goal and an initial screenshot")
    func firstRequestHasContext() async {
        let recorder = LoopRecorder()
        let agent = makeAgent(recorder: recorder, replies: [[.text("All set.")]])

        await agent.run(request: request("open my calendar"), handler: makeHandler(recorder))

        #expect(recorder.requests.count == 1)
        let first = recorder.requests[0].first
        let hasGoal = first?.content.contains {
            if case .text(let t) = $0 { return t.contains("open my calendar") }
            return false
        }
        let hasImage = first?.content.contains {
            if case .image = $0 { return true }
            return false
        }
        #expect(hasGoal == true)
        #expect(hasImage == true)
        #expect(recorder.steps.last == .done("All set."))
    }

    @Test("A tool use is executed and its screenshot fed back as the tool result")
    func toolUseRoundTrip() async {
        let recorder = LoopRecorder()
        let agent = makeAgent(
            recorder: recorder,
            replies: [
                [.toolUse(id: "t1", input: CUInput(action: "left_click", coordinate: [10, 20]))],
                [.text("Clicked it.")],
            ]
        )

        await agent.run(request: request("click the button"), handler: makeHandler(recorder))

        #expect(recorder.actions == ["click"])
        // The follow-up request must answer tool use "t1" with an image result.
        let followUp = recorder.requests[1].last
        let answered = followUp?.content.contains {
            if case .toolResult(let id, let image) = $0 { return id == "t1" && image != nil }
            return false
        }
        #expect(answered == true)
        #expect(recorder.steps.last == .done("Clicked it."))
    }

    @Test("Scroll targets its coordinate by moving the pointer first")
    func scrollMovesFirst() async {
        let recorder = LoopRecorder()
        let agent = makeAgent(
            recorder: recorder,
            replies: [
                [
                    .toolUse(
                        id: "t1",
                        input: CUInput(
                            action: "scroll",
                            coordinate: [50, 60],
                            scrollDirection: "down",
                            scrollAmount: 2
                        )
                    )
                ],
                [.text("Scrolled.")],
            ]
        )

        await agent.run(request: request("scroll the list"), handler: makeHandler(recorder))
        #expect(recorder.actions == ["moveMouse", "scroll"])
    }

    @Test("Cancelling the surrounding task stops the loop quietly")
    func cancellationStops() async {
        let recorder = LoopRecorder()
        let agent = ComputerUseAgent(
            screen: ScreenCaptureClient(capture: { makePNG() }),
            control: ComputerControlClient(perform: { _ in }),
            apiKey: "test-key",
            settle: .zero,
            transport: { _, _, _ in
                try await Task.sleep(for: .seconds(60))
                return [.text("never")]
            }
        )

        let task = Task {
            await agent.run(request: request("wait forever"), handler: makeHandler(recorder))
        }
        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()
        await task.value

        #expect(recorder.steps.last == .done("Cancelled."))
    }

    @Test("An HTTP failure surfaces its status and message")
    func httpErrorSurfaces() async {
        let recorder = LoopRecorder()
        let agent = ComputerUseAgent(
            screen: ScreenCaptureClient(capture: { makePNG() }),
            control: ComputerControlClient(perform: { _ in }),
            apiKey: "test-key",
            settle: .zero,
            transport: { _, _, _ in throw CUError.http(429, "rate limited") }
        )

        await agent.run(request: request("do a thing"), handler: makeHandler(recorder))

        guard case .failed(let message) = recorder.steps.last else {
            Issue.record("expected a failure step")
            return
        }
        #expect(message.contains("429"))
        #expect(message.contains("rate limited"))
    }

    @Test("The step cap fails with a clear message")
    func stepCap() async {
        let recorder = LoopRecorder()
        let alwaysActing: [[CUBlock]] = Array(
            repeating: [.toolUse(id: "t", input: CUInput(action: "screenshot"))],
            count: 20
        )
        let agent = makeAgent(recorder: recorder, replies: alwaysActing)

        await agent.run(request: request("loop forever"), handler: makeHandler(recorder))

        guard case .failed(let message) = recorder.steps.last else {
            Issue.record("expected a failure step")
            return
        }
        #expect(message.contains("15"))
    }
}

@Suite("Key parsing — extended map")
struct KeyParsingTests {
    @Test("Digits, function keys, navigation and punctuation are parseable")
    func extendedKeys() {
        #expect(ComputerUseAgent.parseKey("5")?.0 == 23)
        #expect(ComputerUseAgent.parseKey("f5")?.0 == 96)
        #expect(ComputerUseAgent.parseKey("Page_Down")?.0 == 121)
        #expect(ComputerUseAgent.parseKey("page_up")?.0 == 116)
        #expect(ComputerUseAgent.parseKey("Home")?.0 == 115)
        #expect(ComputerUseAgent.parseKey("end")?.0 == 119)
        #expect(ComputerUseAgent.parseKey("comma")?.0 == 43)
        #expect(ComputerUseAgent.parseKey("period")?.0 == 47)
        #expect(ComputerUseAgent.parseKey("slash")?.0 == 44)
        #expect(ComputerUseAgent.parseKey("minus")?.0 == 27)
        #expect(ComputerUseAgent.parseKey("equal")?.0 == 24)
        #expect(ComputerUseAgent.parseKey("BackSpace")?.0 == 51)
        #expect(ComputerUseAgent.parseKey("forward_delete")?.0 == 117)
        #expect(ComputerUseAgent.parseKey("cmd+shift+4")?.0 == 21)
        #expect(ComputerUseAgent.parseKey("cmd+shift+4")?.1.contains(.maskShift) == true)
    }
}
