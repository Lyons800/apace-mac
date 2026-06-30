import Testing

@testable import ApaceCore

@Suite("Dictation state machine")
struct DictationStateMachineTests {
    let machine = DictationStateMachine()

    @Test("A full dictation runs idle → listening → transcribing → inserting → idle")
    func happyPath() {
        var state = DictationState.idle
        state = machine.reduce(state, on: .startRequested)
        #expect(state == .listening(partial: ""))

        state = machine.reduce(state, on: .partialTranscript("the quick"))
        #expect(state == .listening(partial: "the quick"))

        state = machine.reduce(state, on: .stopRequested)
        #expect(state == .transcribing)

        state = machine.reduce(state, on: .finalTranscript("the quick brown fox"))
        #expect(state == .inserting(text: "the quick brown fox"))

        state = machine.reduce(state, on: .textInserted)
        #expect(state == .idle)
    }

    @Test("An empty final transcript inserts nothing and returns to idle")
    func emptyFinalReturnsToIdle() {
        let state = machine.reduce(.transcribing, on: .finalTranscript(""))
        #expect(state == .idle)
    }

    @Test("Cancel from any active state returns to idle")
    func cancelReturnsToIdle() {
        #expect(machine.reduce(.listening(partial: "x"), on: .cancelled) == .idle)
        #expect(machine.reduce(.transcribing, on: .cancelled) == .idle)
        #expect(machine.reduce(.inserting(text: "x"), on: .cancelled) == .idle)
    }

    @Test("Out-of-order events are ignored")
    func outOfOrderEventsAreIgnored() {
        // A final transcript while idle is meaningless and must not change state.
        #expect(machine.reduce(.idle, on: .finalTranscript("noise")) == .idle)
        // A partial while transcribing arrives too late to matter.
        #expect(machine.reduce(.transcribing, on: .partialTranscript("late")) == .transcribing)
    }

    @Test("A failure is recoverable — the next start clears it")
    func failureIsRecoverable() {
        let failed = machine.reduce(.transcribing, on: .failed("engine unavailable"))
        #expect(failed == .failed(message: "engine unavailable"))
        #expect(machine.reduce(failed, on: .startRequested) == .listening(partial: ""))
    }
}
