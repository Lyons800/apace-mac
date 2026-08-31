import Foundation
import Testing

@testable import ApaceCore

@Suite("Command conversations")
struct CommandConversationTests {
    @Test("Conversation memory is bounded to the latest twelve turns")
    func boundsTurns() {
        var conversation = CommandConversation()
        let start = Date(timeIntervalSince1970: 1_000)
        for index in 0..<15 {
            conversation.append(
                role: index.isMultiple(of: 2) ? .user : .assistant,
                text: "turn \(index)",
                at: start.addingTimeInterval(Double(index))
            )
        }

        #expect(conversation.turns.count == CommandConversation.maximumTurns)
        #expect(conversation.turns.first?.text == "turn 3")
        #expect(conversation.turns.last?.text == "turn 14")
    }

    @Test("Inactive conversation context expires")
    func expires() {
        var conversation = CommandConversation()
        let start = Date(timeIntervalSince1970: 1_000)
        conversation.append(role: .user, text: "draft a reply", at: start)

        #expect(conversation.context(at: start.addingTimeInterval(599)).count == 1)
        #expect(conversation.context(at: start.addingTimeInterval(601)).isEmpty)
        #expect(conversation.lastActivityAt == nil)
    }

    @Test("Risk resolution only upgrades the model classification")
    func riskResolution() {
        #expect(
            CommandActionRisk.resolved(proposed: .readOnly, goal: "send it to João")
                == .externalCommunication
        )
        #expect(
            CommandActionRisk.resolved(proposed: .readOnly, goal: "buy the tickets")
                == .financial
        )
        #expect(
            CommandActionRisk.resolved(proposed: .destructive, goal: "open Calendar")
                == .destructive
        )
        #expect(
            CommandActionRisk.resolved(proposed: .unknown, goal: "open Calendar")
                == .unknown
        )
    }
}
