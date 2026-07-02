import ApaceClients
import ApaceCore
import DictationPipeline
import Observation

/// The observable façade over ``CommandController`` for command mode. It republishes the
/// controller's activity so the notch can show listening, thinking, and the answer.
@Observable
public final class CommandModel {
    public private(set) var activity: CommandActivity = .idle

    private let controller: CommandController

    public init(clients: CommandClients) {
        controller = CommandController(clients: clients)
    }

    /// Starts listening for the command hotkey and mirroring the controller's activity.
    public func activate() {
        let controller = controller
        Task { await controller.run() }
        Task { [weak self] in
            for await activity in controller.activities {
                self?.activity = activity
            }
        }
    }
}
