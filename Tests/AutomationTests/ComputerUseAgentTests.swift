import ApaceClients
import ApaceCore
import CoreGraphics
import Testing

@testable import Automation

@Suite("Computer-use agent")
struct ComputerUseAgentTests {
    @Test("The model receives the exact approval boundary")
    func approvalInstructions() {
        let approved = ComputerUseAgent.instructions(
            request: AutomationRequest(
                goal: "send the drafted message to André",
                risk: .externalCommunication,
                userApproved: true
            )
        )
        #expect(approved.contains("send the drafted message to André"))
        #expect(approved.contains("approved this exact high-impact action"))
        #expect(approved.contains("Do not broaden it"))

        let readOnly = ComputerUseAgent.instructions(
            request: AutomationRequest(
                goal: "open my calendar",
                risk: .readOnly,
                userApproved: false
            )
        )
        #expect(readOnly.contains("classified as read-only"))
        #expect(readOnly.contains("Do not make changes or communicate externally"))
    }

    @Test("Parses key combos into keycode and modifiers")
    func keyParsing() {
        let enter = ComputerUseAgent.parseKey("Return")
        #expect(enter?.0 == 36)
        #expect(enter?.1 == [])

        let paste = ComputerUseAgent.parseKey("cmd+v")
        #expect(paste?.0 == 9)
        #expect(paste?.1.contains(.maskCommand) == true)

        #expect(ComputerUseAgent.parseKey("nonsense-key") == nil)
    }

    @Test("Describes actions for the notch")
    func descriptions() {
        #expect(
            ComputerUseAgent.describe(CUInput(action: "type", coordinate: nil, text: "hi"))
                .contains("hi")
        )
        #expect(
            ComputerUseAgent.describe(CUInput(action: "screenshot", coordinate: nil, text: nil))
                .contains("screen")
        )
    }
}
