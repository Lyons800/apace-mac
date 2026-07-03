import CoreGraphics
import Testing

@testable import Automation

@Suite("Computer-use agent")
struct ComputerUseAgentTests {
    @Test("Flags outward goals as risky, leaves navigation alone")
    func riskDetection() {
        #expect(ComputerUseAgent.isRisky("message André that I'm late"))
        #expect(ComputerUseAgent.isRisky("delete that email"))
        #expect(ComputerUseAgent.isRisky("buy the concert tickets"))
        #expect(!ComputerUseAgent.isRisky("open my calendar"))
        #expect(!ComputerUseAgent.isRisky("scroll down and find the settings"))
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
