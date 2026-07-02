import ApaceClients
import ApaceCore
import Carbon.HIToolbox
import CoreGraphics
import Foundation

extension HotkeyClient {
    /// Dictation push-to-talk: hold Right Option, release to insert.
    public static let live = HotkeyClient(intents: { OptionHotkeyMonitor.shared.dictationIntents() }
    )

    /// Command mode: double-tap Right Option and hold the second tap, release to send.
    /// Shares the Option key with dictation — a single hold dictates, a quick double-tap
    /// hold gives a command — so there's no separate modifier to collide with shortcuts.
    public static let command = HotkeyClient(intents: {
        OptionHotkeyMonitor.shared.commandIntents()
    })
}

/// Watches Right Option through a `CGEvent` tap and routes each hold to one of two
/// streams: a plain hold dictates, a double-tap-and-hold is a command. Distinguishing
/// them needs the timing of the previous tap, so a single monitor owns both streams.
///
/// `@unchecked Sendable`: the tap callback runs on a dedicated run-loop thread while the
/// streams are requested from the setup thread; the small shared state is guarded by
/// `lock`.
final class OptionHotkeyMonitor: @unchecked Sendable {
    static let shared = OptionHotkeyMonitor()

    private let keyCode = CGKeyCode(kVK_RightOption)
    private let modifier: CGEventFlags = .maskAlternate
    /// A press shorter than this counts as a "tap" rather than a hold.
    private let tapMax: TimeInterval = 0.25
    /// The second tap must begin within this of the first tap's release.
    private let gapMax: TimeInterval = 0.3

    private let lock = NSLock()
    private var dictation: AsyncStream<HotkeyIntent>.Continuation?
    private var command: AsyncStream<HotkeyIntent>.Continuation?

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var started = false
    private var isStopped = false

    private enum Gesture { case none, dictation, command }
    private var isPressed = false
    private var current: Gesture = .none
    private var downTime: TimeInterval = 0
    private var lastUpTime: TimeInterval = -1
    private var lastPressWasTap = false

    func dictationIntents() -> AsyncStream<HotkeyIntent> {
        let (stream, continuation) = AsyncStream<HotkeyIntent>.makeStream()
        lock.withLock { dictation = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.lock.withLock { self?.dictation = nil }
        }
        ensureStarted()
        return stream
    }

    func commandIntents() -> AsyncStream<HotkeyIntent> {
        let (stream, continuation) = AsyncStream<HotkeyIntent>.makeStream()
        lock.withLock { command = continuation }
        continuation.onTermination = { [weak self] _ in self?.lock.withLock { self?.command = nil }
        }
        ensureStarted()
        return stream
    }

    private func ensureStarted() {
        let shouldStart = lock.withLock { () -> Bool in
            guard !started, !isStopped else { return false }
            started = true
            return true
        }
        guard shouldStart else { return }
        let thread = Thread { [weak self] in self?.runTap() }
        thread.name = "so.apace.hotkey"
        thread.start()
    }

    /// Creates the session tap. Returns nil until Accessibility is granted.
    private func makeTap() -> CFMachPort? {
        let mask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: optionHotkeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    /// Builds the tap, pumps its run loop, and blocks the dedicated thread until stopped.
    /// Polls for Accessibility so the hotkey starts working the moment permission lands.
    private func runTap() {
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
        let now = ProcessInfo.processInfo.systemUptime

        // Decide which stream this transition belongs to, then yield outside the lock.
        let target: (continuation: AsyncStream<HotkeyIntent>.Continuation?, intent: HotkeyIntent)? =
            lock.withLock {
                guard pressed != isPressed else { return nil }
                isPressed = pressed

                if pressed {
                    let isDoubleTap =
                        lastPressWasTap && lastUpTime >= 0 && (now - lastUpTime) < gapMax
                    downTime = now
                    current = isDoubleTap ? .command : .dictation
                    return (isDoubleTap ? command : dictation, .startDictation)
                } else {
                    lastPressWasTap = (now - downTime) < tapMax
                    lastUpTime = now
                    let gesture = current
                    current = .none
                    switch gesture {
                    case .command: return (command, .stopDictation)
                    case .dictation: return (dictation, .stopDictation)
                    case .none: return nil
                    }
                }
            }

        if let target {
            target.continuation?.yield(target.intent)
        }
    }

    private func stop() {
        let (tap, loop) = lock.withLock {
            isStopped = true
            return (eventTap, runLoop)
        }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let loop { CFRunLoopStop(loop) }
    }
}

/// Top-level, non-capturing callback so it can be used as a C function pointer. It
/// trampolines straight back into the owning ``OptionHotkeyMonitor``.
private let optionHotkeyCallback: CGEventTapCallBack = { _, type, event, userInfo in
    if let userInfo {
        Unmanaged<OptionHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue().handle(
            type,
            event
        )
    }
    return Unmanaged.passUnretained(event)
}
