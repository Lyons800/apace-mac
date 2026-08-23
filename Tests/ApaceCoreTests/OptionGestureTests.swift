import Testing

@testable import ApaceCore

@Suite("Option-key gesture machine")
struct OptionGestureTests {
    // Times are plain seconds; the machine only compares differences.

    @Test("A long hold dictates: start on press, stop on release")
    func holdDictates() {
        var gesture = OptionGesture()
        #expect(gesture.pressed(at: 0) == .init(route: .dictation, intent: .startDictation))
        #expect(gesture.released(at: 1.0) == .init(route: .dictation, intent: .stopDictation))
    }

    @Test("A quick tap cancels dictation instead of stopping it")
    func tapCancels() {
        var gesture = OptionGesture()
        #expect(gesture.pressed(at: 0) == .init(route: .dictation, intent: .startDictation))
        // Released inside the tap window: this may be the first half of a double-tap
        // command, so the dictation that optimistically started must be cancelled —
        // not stopped, which would run the transcribe-and-insert path.
        #expect(gesture.released(at: 0.1) == .init(route: .dictation, intent: .cancel))
    }

    @Test("A double-tap-and-hold routes the second press to command mode")
    func doubleTapCommands() {
        var gesture = OptionGesture()
        _ = gesture.pressed(at: 0)
        _ = gesture.released(at: 0.1)
        #expect(gesture.pressed(at: 0.25) == .init(route: .command, intent: .startDictation))
        #expect(gesture.released(at: 1.5) == .init(route: .command, intent: .stopDictation))
    }

    @Test("A second press after the gap window is dictation again")
    func slowSecondTapDictates() {
        var gesture = OptionGesture()
        _ = gesture.pressed(at: 0)
        _ = gesture.released(at: 0.1)
        // 0.5s after the release — past gapMax, so not a double-tap.
        #expect(gesture.pressed(at: 0.6) == .init(route: .dictation, intent: .startDictation))
    }

    @Test("A tap that follows a long hold does not start a command")
    func tapAfterHoldIsNotDoubleTap() {
        var gesture = OptionGesture()
        _ = gesture.pressed(at: 0)
        _ = gesture.released(at: 1.0)  // a hold, not a tap
        #expect(gesture.pressed(at: 1.1) == .init(route: .dictation, intent: .startDictation))
    }

    @Test("Repeated press or release events are ignored")
    func duplicateTransitionsIgnored() {
        var gesture = OptionGesture()
        #expect(gesture.pressed(at: 0) != nil)
        #expect(gesture.pressed(at: 0.05) == nil)
        #expect(gesture.released(at: 0.5) != nil)
        #expect(gesture.released(at: 0.6) == nil)
    }

    @Test("Recovery cancels an active hold and resets the gesture")
    func recoveryCancellation() {
        var gesture = OptionGesture()
        _ = gesture.pressed(at: 0)
        #expect(gesture.cancelCurrent() == .init(route: .dictation, intent: .cancel))
        #expect(gesture.cancelCurrent() == nil)
        #expect(gesture.pressed(at: 1) == .init(route: .dictation, intent: .startDictation))
    }

    @Test("Release recovery ignores one stale modifier-state sample")
    func releaseWatchdogDebouncesState() {
        var watchdog = ModifierReleaseWatchdog()
        let firstMiss = watchdog.observe(isPressed: false)
        let pressedAgain = watchdog.observe(isPressed: true)
        let nextMiss = watchdog.observe(isPressed: false)
        let confirmedRelease = watchdog.observe(isPressed: false)

        #expect(!firstMiss)
        #expect(!pressedAgain)
        #expect(!nextMiss)
        #expect(confirmedRelease)
    }
}
