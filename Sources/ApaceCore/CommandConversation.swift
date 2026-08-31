import Foundation

/// One turn in Apace's short-lived command conversation. Command history is deliberately
/// kept in memory: follow-ups work while the user is in the flow, without creating a new
/// persistent transcript store containing screen-aware questions and answers.
public struct CommandTurn: Equatable, Sendable, Identifiable {
    public enum Role: String, Equatable, Sendable {
        case user
        case assistant
    }

    public let id: UUID
    public let role: Role
    public let text: String
    public let date: Date

    public init(id: UUID = UUID(), role: Role, text: String, date: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }
}

/// A bounded, expiring command session. Keeping this rule in the domain makes the same
/// follow-up semantics available to the router, UI, and tests without tying them to a
/// particular model provider.
public struct CommandConversation: Equatable, Sendable {
    public static let defaultLifetime: TimeInterval = 10 * 60
    public static let maximumTurns = 12

    public private(set) var turns: [CommandTurn]
    public private(set) var lastActivityAt: Date?

    public init(turns: [CommandTurn] = [], lastActivityAt: Date? = nil) {
        self.turns = Array(turns.suffix(Self.maximumTurns))
        self.lastActivityAt = lastActivityAt ?? self.turns.last?.date
    }

    /// Returns the active context, clearing stale turns before a new request is routed.
    public mutating func context(
        at now: Date,
        lifetime: TimeInterval = Self.defaultLifetime
    ) -> [CommandTurn] {
        if let lastActivityAt, now.timeIntervalSince(lastActivityAt) > lifetime {
            reset()
        }
        return turns
    }

    public mutating func append(
        role: CommandTurn.Role,
        text: String,
        at now: Date
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        turns.append(CommandTurn(role: role, text: trimmed, date: now))
        if turns.count > Self.maximumTurns {
            turns.removeFirst(turns.count - Self.maximumTurns)
        }
        lastActivityAt = now
    }

    public mutating func reset() {
        turns.removeAll()
        lastActivityAt = nil
    }
}

/// The consequence class of a computer-control goal. This is separate from the model's
/// low-level click/key actions so approval policy can be applied before control begins.
public enum CommandActionRisk: String, Equatable, Sendable, Codable, CaseIterable {
    case readOnly
    case localChange
    case externalCommunication
    case destructive
    case financial
    case sensitive
    case unknown

    public var requiresApproval: Bool {
        switch self {
        case .readOnly: false
        case .localChange, .externalCommunication, .destructive, .financial, .sensitive, .unknown:
            true
        }
    }

    public var approvalTitle: String {
        switch self {
        case .readOnly: "Review this action"
        case .localChange: "Allow this change?"
        case .externalCommunication: "Send this externally?"
        case .destructive: "Allow this destructive action?"
        case .financial: "Allow this financial action?"
        case .sensitive: "Share or use sensitive information?"
        case .unknown: "Run this action?"
        }
    }

    /// Never lets the router's classification downgrade an obviously consequential
    /// goal. The model remains the primary classifier; this small local backstop catches
    /// the most common outward, destructive, financial, and sensitive actions even if
    /// a malformed or manipulated reply labels them read-only.
    public static func resolved(
        proposed: CommandActionRisk,
        goal: String
    ) -> CommandActionRisk {
        let words = Set(
            goal.lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        )
        let detected: CommandActionRisk
        if words.containsAny([
            "pay", "purchase", "buy", "checkout", "book", "order", "subscribe", "transfer",
        ]) {
            detected = .financial
        } else if words.containsAny([
            "delete", "erase", "remove", "trash", "cancel",
        ]) {
            detected = .destructive
        } else if words.containsAny([
            "send", "message", "email", "reply", "post", "publish", "submit", "call", "invite",
            "share",
        ]) {
            detected = .externalCommunication
        } else if words.containsAny([
            "password", "passcode", "authentication", "verification", "private", "card", "bank",
        ]) {
            detected = .sensitive
        } else if words.containsAny([
            "install", "create", "edit", "change", "rename", "move", "save", "upload", "download",
            "enable", "disable",
        ]) {
            detected = .localChange
        } else {
            detected = .readOnly
        }
        return detected.priority > proposed.priority ? detected : proposed
    }

    private var priority: Int {
        switch self {
        case .readOnly: 0
        case .localChange: 1
        case .externalCommunication: 2
        case .destructive: 3
        case .financial: 4
        case .sensitive: 5
        case .unknown: 6
        }
    }
}

private extension Set where Element == String {
    func containsAny(_ candidates: [String]) -> Bool {
        candidates.contains(where: contains)
    }
}
