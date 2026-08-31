import ApaceClients
import ApaceCore
import Carbon.HIToolbox
import CoreGraphics
import Foundation

extension HotkeyClient {
    /// Global dictation shortcut, using the key and hold/toggle behaviour from Settings.
    public static let live = HotkeyClient(intents: { OptionHotkeyMonitor.shared.dictationIntents() }
    )

    /// Command mode: double-tap the chosen modifier and hold the second tap, release to send.
    /// Shares the shortcut with dictation — a single hold dictates, a quick double-tap
    /// hold gives a command — so there's no separate modifier to collide with shortcuts.
    public static let command = HotkeyClient(intents: {
        OptionHotkeyMonitor.shared.commandIntents()
    })
}

/// Watches the chosen modifier through a `CGEvent` tap and routes each hold to one of two
/// streams: a plain hold dictates, a double-tap-and-hold is a command. Distinguishing
/// them needs the timing of the previous tap, so a single monitor owns both streams.
///
/// `@unchecked Sendable`: the tap callback runs on a dedicated run-loop thread while the
/// streams are requested from the setup thread; the small shared state is guarded by
/// `lock`.
final class OptionHotkeyMonitor: @unchecked Sendable {
    static let shared = OptionHotkeyMonitor()

    private let lock = NSLock()
    private var dictation: AsyncStream<HotkeyIntent>.Continuation?
    private var command: AsyncStream<HotkeyIntent>.Continuation?

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var started = false
    private var isStopped = false
    private var watchdogGeneration = 0

    /// The tap/hold/double-tap timing rules, kept pure so they're tested directly.
    private var gesture = OptionGesture()

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
        let mask =
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)
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
            cancelActiveGesture()
            if let tap = lock.withLock({ eventTap }) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        if type == .keyDown, isCancelEvent(event) {
            DictationHealthRecorder.shared.record(.hotkey("Cancel shortcut pressed"))
            cancelAll()
            return
        }

        let shortcut = DictationShortcutPreference.activation
        let keyCode = Self.keyCode(for: shortcut)
        let modifier = Self.modifier(for: shortcut)

        guard type == .flagsChanged,
            event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode)
        else { return }

        let pressed = event.flags.contains(modifier)
        let now = ProcessInfo.processInfo.systemUptime
        var watchdog: Int?

        if DictationShortcutPreference.mode == .handsFree {
            guard pressed else { return }
            lock.withLock { gesture = OptionGesture() }
            DictationHealthRecorder.shared.record(
                .hotkey("\(shortcut.displayName) pressed (hands-free toggle)")
            )
            lock.withLock { dictation }?.yield(.toggleDictation)
            return
        }

        // Decide which stream this transition belongs to, then yield outside the lock.
        let target: (continuation: AsyncStream<HotkeyIntent>.Continuation?, intent: HotkeyIntent)? =
            lock.withLock {
                let output: OptionGesture.Output?
                if pressed {
                    output = gesture.pressed(at: now)
                    if output != nil {
                        watchdogGeneration &+= 1
                        watchdog = watchdogGeneration
                    }
                } else {
                    watchdogGeneration &+= 1
                    output = gesture.released(at: now)
                }
                guard let output
                else { return nil }
                switch output.route {
                case .dictation: return (dictation, output.intent)
                case .command: return (command, output.intent)
                }
            }

        if let target {
            let action = pressed ? "pressed" : "released"
            DictationHealthRecorder.shared.record(
                .hotkey("\(shortcut.displayName) \(action)")
            )
            target.continuation?.yield(target.intent)
        }
        if let watchdog {
            startReleaseWatchdog(generation: watchdog, modifier: modifier)
        }
    }

    /// Reconciles the logical gesture with the physical shortcut key. macOS can
    /// drop a `flagsChanged` key-up while disabling or rebuilding an event tap; in that
    /// case cancel safely instead of leaving the microphone running indefinitely.
    private func startReleaseWatchdog(generation: Int, modifier: CGEventFlags) {
        Task.detached { [weak self] in
            guard let self else { return }
            var releaseWatchdog = ModifierReleaseWatchdog()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                let stillCurrent = self.lock.withLock {
                    self.watchdogGeneration == generation && !self.isStopped
                }
                guard stillCurrent else { return }

                // Modifier keys are represented in the source's flag state.
                // `keyState` is not reliable for modifier-only keys and caused v0.1.8
                // to cancel every recording shortly after it started.
                let optionPressed = CGEventSource.flagsState(.combinedSessionState)
                    .contains(modifier)
                if releaseWatchdog.observe(isPressed: optionPressed) {
                    self.cancelActiveGesture(generation: generation)
                    return
                }
            }
        }
    }

    private func cancelActiveGesture(generation: Int? = nil) {
        let target: (continuation: AsyncStream<HotkeyIntent>.Continuation?, intent: HotkeyIntent)? =
            lock.withLock {
                if let generation, generation != watchdogGeneration { return nil }
                watchdogGeneration &+= 1
                guard let output = gesture.cancelCurrent() else { return nil }
                switch output.route {
                case .dictation: return (dictation, output.intent)
                case .command: return (command, output.intent)
                }
            }
        if let target {
            target.continuation?.yield(target.intent)
        }
    }

    private func cancelAll() {
        cancelActiveGesture()
        let continuations = lock.withLock { (dictation, command) }
        continuations.0?.yield(.cancel)
        continuations.1?.yield(.cancel)
    }

    private func isCancelEvent(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch DictationShortcutPreference.cancel {
        case .escape:
            return keyCode == Int64(kVK_Escape)
        case .commandPeriod:
            return keyCode == Int64(kVK_ANSI_Period) && event.flags.contains(.maskCommand)
        }
    }

    private static func keyCode(for key: DictationActivationKey) -> CGKeyCode {
        switch key {
        case .rightOption: CGKeyCode(kVK_RightOption)
        case .leftOption: CGKeyCode(kVK_Option)
        case .rightControl: CGKeyCode(kVK_RightControl)
        case .leftControl: CGKeyCode(kVK_Control)
        case .function: CGKeyCode(kVK_Function)
        }
    }

    private static func modifier(for key: DictationActivationKey) -> CGEventFlags {
        switch key {
        case .rightOption, .leftOption: .maskAlternate
        case .rightControl, .leftControl: .maskControl
        case .function: .maskSecondaryFn
        }
    }

    private func stop() {
        cancelActiveGesture()
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
