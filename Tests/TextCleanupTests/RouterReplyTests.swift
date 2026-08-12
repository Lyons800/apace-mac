import ApaceCore
import Testing

@testable import TextCleanup

@Suite("Router reply parsing")
struct RouterReplyTests {
    @Test("A bare JSON object parses into its decision")
    func bareJSON() {
        #expect(
            RouterReply.parse(#"{"action":"answer","text":"It's a linker error."}"#)
                == .answer("It's a linker error.")
        )
        #expect(
            RouterReply.parse(#"{"action":"insert","text":"até já","replace":true}"#)
                == .insert(text: "até já", replacesDraft: true)
        )
        #expect(RouterReply.parse(#"{"action":"control"}"#) == .control)
    }

    @Test("An insert without a replace flag defaults to typing at the cursor")
    func replaceDefaultsFalse() {
        #expect(
            RouterReply.parse(#"{"action":"insert","text":"olá"}"#)
                == .insert(text: "olá", replacesDraft: false)
        )
    }

    @Test("Code fences and surrounding prose are tolerated")
    func fencedAndWrapped() {
        let fenced = """
            ```json
            {"action":"insert","text":"até às oito","replace":true}
            ```
            """
        #expect(RouterReply.parse(fenced) == .insert(text: "até às oito", replacesDraft: true))

        let wrapped = #"Sure! Here you go: {"action":"answer","text":"Done"} — anything else?"#
        #expect(RouterReply.parse(wrapped) == .answer("Done"))
    }

    @Test("Braces inside strings don't derail the object scan")
    func bracesInStrings() {
        #expect(
            RouterReply.parse(#"{"action":"answer","text":"use { and } sparingly"}"#)
                == .answer("use { and } sparingly")
        )
    }

    @Test("Prose, unknown actions, and empty text are rejected, not misread")
    func rejects() {
        #expect(RouterReply.parse("I'm not sure what you mean.") == nil)
        #expect(RouterReply.parse(#"{"action":"dance"}"#) == nil)
        #expect(RouterReply.parse(#"{"action":"insert","text":""}"#) == nil)
        #expect(RouterReply.parse(#"{"action":"answer"}"#) == nil)
    }
}
