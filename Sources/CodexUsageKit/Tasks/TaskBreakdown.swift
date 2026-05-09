import Foundation

public struct UsageBucket: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let tokens: Int
    public let threadCount: Int

    public init(name: String, tokens: Int, threadCount: Int) {
        self.id = name
        self.name = name
        self.tokens = tokens
        self.threadCount = threadCount
    }
}

public struct TaskBreakdownWindow: Equatable, Sendable {
    public let projects: [UsageBucket]
    public let models: [UsageBucket]

    public init(projects: [UsageBucket], models: [UsageBucket]) {
        self.projects = projects
        self.models = models
    }
}

public struct TaskBreakdownSnapshot: Equatable, Sendable {
    public let fiveHours: TaskBreakdownWindow
    public let sevenDays: TaskBreakdownWindow

    public init(fiveHours: TaskBreakdownWindow, sevenDays: TaskBreakdownWindow) {
        self.fiveHours = fiveHours
        self.sevenDays = sevenDays
    }

    public static let empty = TaskBreakdownSnapshot(
        fiveHours: .init(projects: [], models: []),
        sevenDays: .init(projects: [], models: [])
    )
}
