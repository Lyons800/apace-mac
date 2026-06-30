import ApaceClients
import ApaceCore
import DictationPipeline
import Foundation
import Observation

/// The observable store backing the dictation surface (the notch overlay).
///
/// It owns a ``DictationController`` and republishes its state transitions onto the
/// main actor for SwiftUI to read. The controller does the real work off the main
/// actor; this type is the thin, observable bridge to the UI. High-frequency data
/// (audio levels, volatile partials) is throttled before it reaches here so the
/// render path stays cheap.
@Observable
public final class DictationModel {
    public private(set) var state: DictationState = .idle

    private let controller: DictationController
    private let tasks = TaskBag()
    private var isActive = false

    /// Builds the model around a set of ports. The app passes the live adapters; tests
    /// pass fakes.
    public init(clients: DictationClients) {
        controller = DictationController(clients: clients)
    }

    /// Starts observing the controller and listening for hotkey intents. Idempotent;
    /// call once when the UI appears.
    public func activate() {
        guard !isActive else { return }
        isActive = true

        let transitions = controller.states
        tasks.add(
            Task { [weak self] in
                for await state in transitions {
                    self?.state = state
                }
            }
        )
        tasks.add(
            Task { [controller] in
                await controller.run()
            }
        )
    }

    /// Forwards an intent from a source other than the hotkey — a menu item, or a test.
    public func send(_ intent: HotkeyIntent) async {
        await controller.handle(intent)
    }

    deinit {
        tasks.cancelAll()
    }
}

/// Holds the model's long-running tasks so they can be cancelled from `deinit`, which
/// is nonisolated and so can't reach the main-actor-isolated store directly.
private nonisolated final class TaskBag: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [Task<Void, Never>] = []

    func add(_ task: Task<Void, Never>) {
        lock.withLock { tasks.append(task) }
    }

    func cancelAll() {
        lock.withLock {
            for task in tasks { task.cancel() }
            tasks.removeAll()
        }
    }
}
