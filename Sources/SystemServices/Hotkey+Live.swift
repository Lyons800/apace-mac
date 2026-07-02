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

    /// Command mode's push-to-talk, on Right Command. Because Command is also the
    /// shortcut modifier, this monitor waits a beat before activating and cancels the
    /// moment any other key is pressed — so Cmd-C, Cmd-Shift-4 and friends never trigger
    /// it. Hold Right Command *on its own* to speak a command.
    public static let command = HotkeyClient(intents: { HotkeyMonitor.rightCommand.intents() })
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

    static let rightCommand = HotkeyMonitor(
        keyCode: CGKeyCode(kVK_RightCommand),
        modifier: .maskCommand,
        startDelay: 0.3,
        cancelOnKeyDown: true
    )

    private let keyCode: CGKeyCode
    private let modifier: CGEventFlags
    /// Wait this long, holding the key alone, before activating. Zero = immediate.
    private let startDelay: TimeInterval
    /// Cancel a pending/active session if any other key is pressed (i.e. it's a shortcut).
    private let cancelOnKeyDown: Bool
    private let lock = NSLock()
    private let delayQueue = DispatchQueue(label: "so.apace.hotkey.delay")

    private var continuation: AsyncStream<HotkeyIntent>.Continuation?
    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var isPressed = false
    private var isStopped = false
    private var pendingStart: DispatchWorkItem?
    private var isActive = false

    init(
        keyCode: CGKeyCode,
        modifier: CGEventFlags,
        startDelay: TimeInterval = 0,
        cancelOnKeyDown: Bool = false
    ) {
        self.keyCode = keyCode
        self.modifier = modifier
        self.startDelay = startDelay
        self.cancelOnKeyDown = cancelOnKeyDown
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
        var mask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        if cancelOnKeyDown {
            mask |= CGEventMask(1) << CGEventType.keyDown.rawValue
        }
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

        // Any other key pressed while our modifier is held means the user is doing a
        // shortcut, not holding the key on its own — abort.
        if cancelOnKeyDown, type == .keyDown {
            cancelPending()
            return
        }

        guard type == .flagsChanged,
            event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode)
        else { return }

        let pressed = event.flags.contains(modifier)

        if startDelay > 0 {
            handleDelayed(pressed: pressed)
        } else {
            handleImmediate(pressed: pressed)
        }
    }

    /// The simple path: press starts, release stops, right away.
    private func handleImmediate(pressed: Bool) {
        let intent: HotkeyIntent? = lock.withLock {
            guard pressed != isPressed else { return nil }
            isPressed = pressed
            return pressed ? .startDictation : .stopDictation
        }
        if let intent {
            yield(intent)
        }
    }

    /// The guarded path: only activate after holding the key alone past `startDelay`,
    /// and cancel if released early or interrupted by another key.
    private func handleDelayed(pressed: Bool) {
        if pressed {
            let work = DispatchWorkItem { [weak self] in self?.fireStart() }
            lock.withLock {
                pendingStart?.cancel()
                pendingStart = work
            }
            delayQueue.asyncAfter(deadline: .now() + startDelay, execute: work)
        } else {
            let wasActive = lock.withLock { () -> Bool in
                pendingStart?.cancel()
                pendingStart = nil
                let active = isActive
                isActive = false
                return active
            }
            if wasActive { yield(.stopDictation) }
        }
    }

    /// Fires when the key has been held alone long enough to count as intentional.
    private func fireStart() {
        let start = lock.withLock { () -> Bool in
            guard pendingStart != nil else { return false }  // cancelled meanwhile
            pendingStart = nil
            isActive = true
            return true
        }
        if start { yield(.startDictation) }
    }

    /// Drops a pending or active guarded session (used when a shortcut is detected).
    private func cancelPending() {
        let wasActive = lock.withLock { () -> Bool in
            pendingStart?.cancel()
            pendingStart = nil
            let active = isActive
            isActive = false
            return active
        }
        if wasActive { yield(.cancel) }
    }

    private func yield(_ intent: HotkeyIntent) {
        lock.withLock { continuation }?.yield(intent)
    }

    private func stop() {
        let (tap, loop, continuation) = lock.withLock {
            isStopped = true
            pendingStart?.cancel()
            pendingStart = nil
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
