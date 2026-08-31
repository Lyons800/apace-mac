import ApaceClients
import ApaceCore
import Testing

@testable import TextCleanup

@Suite("Router reply parsing")
struct RouterReplyTests {
    @Test("A visible WhatsApp conversation gets explicit draft-only guidance")
    func whatsAppDraftPrompt() {
        let prompt = RouterPrompt.build(
            request: "respond to this person in Portuguese",
            field: FocusedField(appName: "WhatsApp", text: ""),
            hasScreenshot: true
        )

        #expect(prompt.contains("A current screenshot is attached"))
        #expect(prompt.contains("Reply-drafting workflow"))
        #expect(prompt.contains("return insert JSON"))
        #expect(prompt.contains("Do not send it"))
    }

    @Test("Reply drafting refuses to pretend it read context without a screenshot")
    func replyDraftWithoutScreenshot() {
        let prompt = RouterPrompt.build(
            request: "draft a reply",
            field: FocusedField(appName: "WhatsApp"),
            hasScreenshot: false
        )

        #expect(prompt.contains("No screenshot is attached"))
        #expect(prompt.contains("Ask the user to turn on screen visibility"))
    }

    @Test("Natural say-back phrasing activates visible reply drafting")
    func naturalReplyDraftPrompt() {
        let prompt = RouterPrompt.build(
            request: "what should I say back in Portuguese?",
            field: FocusedField(appName: "WhatsApp"),
            hasScreenshot: true
        )

        #expect(prompt.contains("Reply-drafting workflow"))
        #expect(prompt.contains("Do not send it"))
    }

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
        #expect(
            RouterReply.parse(
                #"{"action":"control","goal":"open Calendar","risk":"readOnly"}"#
            ) == .control(goal: "open Calendar", risk: .readOnly)
        )
    }

    @Test("Legacy control replies fall back to the spoken goal and require review")
    func controlFallback() {
        #expect(
            RouterReply.parse(#"{"action":"control"}"#, fallbackGoal: "open my calendar")
                == .control(goal: "open my calendar", risk: .unknown)
        )
        #expect(
            RouterReply.parse(
                #"{"action":"control","goal":"do the thing","risk":"unexpected"}"#
            ) == .control(goal: "do the thing", risk: .unknown)
        )
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
