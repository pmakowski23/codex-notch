import Foundation

public struct TokenUsage: Codable, Equatable, Sendable {
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let reasoningOutputTokens: Int
    public let totalTokens: Int

    public init(
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        reasoningOutputTokens: Int,
        totalTokens: Int
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.totalTokens = totalTokens
    }
}

public struct WindowUsage: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let windowMinutes: Int
    public let resetsAt: Date

    public init(usedPercent: Double, windowMinutes: Int, resetsAt: Date) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }
}

public struct RateLimits: Codable, Equatable, Sendable {
    public let primary: WindowUsage
    public let secondary: WindowUsage
    public let planType: String?
    public let rateLimitReachedType: String?

    public init(
        primary: WindowUsage,
        secondary: WindowUsage,
        planType: String?,
        rateLimitReachedType: String?
    ) {
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
        self.rateLimitReachedType = rateLimitReachedType
    }
}

public struct TokenCountEvent: Equatable, Sendable {
    public let eventTimestamp: Date
    public let totalTokenUsage: TokenUsage?
    public let lastTokenUsage: TokenUsage?
    public let rateLimits: RateLimits

    public init(
        eventTimestamp: Date,
        totalTokenUsage: TokenUsage?,
        lastTokenUsage: TokenUsage?,
        rateLimits: RateLimits
    ) {
        self.eventTimestamp = eventTimestamp
        self.totalTokenUsage = totalTokenUsage
        self.lastTokenUsage = lastTokenUsage
        self.rateLimits = rateLimits
    }
}

struct RolloutEnvelope: Decodable {
    let timestamp: String?
    let type: String
    let payload: RolloutPayload?
}

struct RolloutPayload: Decodable {
    let type: String
    let info: RolloutInfo?
    let rateLimits: RolloutRateLimits?

    enum CodingKeys: String, CodingKey {
        case type
        case info
        case rateLimits = "rate_limits"
    }
}

struct RolloutInfo: Decodable {
    let totalTokenUsage: TokenUsage?
    let lastTokenUsage: TokenUsage?

    enum CodingKeys: String, CodingKey {
        case totalTokenUsage = "total_token_usage"
        case lastTokenUsage = "last_token_usage"
    }
}

struct RolloutRateLimits: Decodable {
    let primary: RolloutWindowUsage
    let secondary: RolloutWindowUsage
    let planType: String?
    let rateLimitReachedType: String?

    enum CodingKeys: String, CodingKey {
        case primary
        case secondary
        case planType = "plan_type"
        case rateLimitReachedType = "rate_limit_reached_type"
    }
}

struct RolloutWindowUsage: Decodable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
    }
}

extension RolloutWindowUsage {
    func asWindowUsage() -> WindowUsage {
        WindowUsage(
            usedPercent: usedPercent,
            windowMinutes: windowMinutes,
            resetsAt: Date(timeIntervalSince1970: resetsAt)
        )
    }
}

extension RolloutRateLimits {
    func asRateLimits() -> RateLimits {
        RateLimits(
            primary: primary.asWindowUsage(),
            secondary: secondary.asWindowUsage(),
            planType: planType,
            rateLimitReachedType: rateLimitReachedType
        )
    }
}

extension TokenUsage {
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }
}
