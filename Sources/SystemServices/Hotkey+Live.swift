import ApaceClients
import ApaceCore
import Carbon.HIToolbox
import CoreGraphics
import Foundation

extension HotkeyClient {
    /// Global push-to-talk via a session-level `CGEvent` tap: hold the hotkey to
    /// dictate, release to insert. Defaults to Right Option; the key becomes
    /// configurable in the settings milestone.
    ///
    /// Requires Accessibility (and Input Monitoring) permission. Without it the tap
    /// can't be created and the stream simply stays quiet — onboarding is responsible
    /// for getting the grant.
    public static let live = HotkeyClient(intents: { HotkeyMonitor.rightOption.intents() })
}

/// Watches a single modifier key through a `CGEvent` tap and turns its press and
/// release into dictation intents.
///
/// `@unchecked Sendable` because the tap callback fires on a dedicated run-loop thread
/// while `intents()` is called from the app's setup thread; the shared state is small
/// and guarded by `lock`. Reading the live flag state on every event (rather than
/// toggling a remembered bool) is what stops recording from sticking "on" after a
/// missed key-up.
final class HotkeyMonitor: @unchecked Sendable {
    static let rightOption = HotkeyMonitor(
        keyCode: CGKeyCode(kVK_RightOption),
        modifier: .maskAlternate
    )

    private let keyCode: CGKeyCode
    private let modifier: CGEventFlags
    private let lock = NSLock()

    private var continuation: AsyncStream<HotkeyIntent>.Continuation?
    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var isPressed = false
    private var isStopped = false

    init(keyCode: CGKeyCode, modifier: CGEventFlags) {
        self.keyCode = keyCode
        self.modifier = modifier
    }

    func intents() -> AsyncStream<HotkeyIntent> {
        let (stream, continuation) = AsyncStream<HotkeyIntent>.makeStream()
        lock.withLock { self.continuation = continuation }
        continuation.onTermination = { [weak self] _ in self?.stop() }

        let thread = Thread { [weak self] in self?.runTap() }
        thread.name = "so.apace.hotkey"
        thread.start()

        return stream
    }

    /// Creates the session tap. Returns nil until Accessibility is granted.
    private func makeTap() -> CFMachPort? {
        let mask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: hotkeyEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    /// Builds the tap, pumps its run loop, and blocks the dedicated thread until the
    /// loop is stopped from `stop()`.
    private func runTap() {
        // The tap needs Accessibility. If it isn't granted yet the user may be enabling
        // it right now, so poll until we can create it rather than giving up — that's
        // what lets the hotkey start working the moment permission lands, no restart.
        var tap = makeTap()
        while tap == nil {
            if lock.withLock({ isStopped }) { return }
            Thread.sleep(forTimeInterval: 1.5)
            tap = makeTap()
        }
        guard let tap else { return }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        let loop = CFRunLoopGetCurrent()
        lock.withLock {
            eventTap = tap
            runLoop = loop
        }
        CFRunLoopAddSource(loop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()

        lock.withLock {
            eventTap = nil
            runLoop = nil
        }
    }

    /// Called from the tap callback on the run-loop thread.
    func handle(_ type: CGEventType, _ event: CGEvent) {
        // The system disables a tap that is slow or interrupted; re-enable it so the
        // hotkey survives sleep/wake and heavy load.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = lock.withLock({ eventTap }) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        guard type == .flagsChanged,
            event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode)
        else { return }

        let pressed = event.flags.contains(modifier)
        let intent: HotkeyIntent? = lock.withLock {
            guard pressed != isPressed else { return nil }
            isPressed = pressed
            return pressed ? .startDictation : .stopDictation
        }
        if let intent {
            lock.withLock { continuation }?.yield(intent)
        }
    }

    private func stop() {
        let (tap, loop, continuation) = lock.withLock {
            isStopped = true
            return (eventTap, runLoop, self.continuation)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let loop {
            CFRunLoopStop(loop)
        }
        continuation?.finish()
        lock.withLock { self.continuation = nil }
    }
}

/// Top-level, non-capturing callback so it can be used as a C function pointer. It
/// trampolines straight back into the owning ``HotkeyMonitor``.
private let hotkeyEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    if let userInfo {
        Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
    }
    return Unmanaged.passUnretained(event)
}
