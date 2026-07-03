import ApaceClients

extension AutomationClient {
    /// The production automation client: drives the Mac with Claude's computer-use loop,
    /// using the injected screen/control ports and the user's Anthropic key.
    public static func live(
        screen: ScreenCaptureClient,
        control: ComputerControlClient,
        apiKey: @escaping @Sendable () -> String?
    ) -> AutomationClient {
        AutomationClient { goal, handler in
            guard let key = apiKey(), !key.isEmpty else {
                handler.onStep(.failed("Add an Anthropic API key to run commands."))
                return
            }
            let agent = ComputerUseAgent(screen: screen, control: control, apiKey: key)
            await agent.run(goal: goal, handler: handler)
        }
    }
}
