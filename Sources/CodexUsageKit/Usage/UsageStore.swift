import Foundation
import Observation

public struct UsageSnapshot: Equatable, Sendable {
    public let updatedAt: Date
    public let rateLimits: RateLimits
    public let primaryProjection: BurnRateProjection?
    public let secondaryProjection: BurnRateProjection?
    public let breakdown: TaskBreakdownSnapshot

    public init(
        updatedAt: Date,
        rateLimits: RateLimits,
        primaryProjection: BurnRateProjection?,
        secondaryProjection: BurnRateProjection?,
        breakdown: TaskBreakdownSnapshot
    ) {
        self.updatedAt = updatedAt
        self.rateLimits = rateLimits
        self.primaryProjection = primaryProjection
        self.secondaryProjection = secondaryProjection
        self.breakdown = breakdown
    }
}

@MainActor
@Observable
public final class UsageStore {
    public private(set) var latestEvent: TokenCountEvent?
    public private(set) var breakdown: TaskBreakdownSnapshot = .empty
    public private(set) var primaryProjection: BurnRateProjection?
    public private(set) var secondaryProjection: BurnRateProjection?

    private var primarySamples: [BurnRateSample] = []
    private var secondarySamples: [BurnRateSample] = []
    private let maxSamples = 60

    public init() {}

    public func apply(event: TokenCountEvent, now: Date = Date()) {
        latestEvent = event
        appendSamples(from: event)
        primaryProjection = BurnRate.project(
            samples: primarySamples,
            currentWindow: event.rateLimits.primary,
            now: now
        )
        secondaryProjection = BurnRate.project(
            samples: secondarySamples,
            currentWindow: event.rateLimits.secondary,
            now: now
        )
    }

    public func updateBreakdown(_ value: TaskBreakdownSnapshot) {
        breakdown = value
    }

    public func makeSnapshot(now: Date = Date()) -> UsageSnapshot? {
        guard let latestEvent else {
            return nil
        }
        return UsageSnapshot(
            updatedAt: now,
            rateLimits: latestEvent.rateLimits,
            primaryProjection: primaryProjection,
            secondaryProjection: secondaryProjection,
            breakdown: breakdown
        )
    }

    private func appendSamples(from event: TokenCountEvent) {
        primarySamples.append(.init(
            timestamp: event.eventTimestamp,
            usedPercent: event.rateLimits.primary.usedPercent
        ))
        secondarySamples.append(.init(
            timestamp: event.eventTimestamp,
            usedPercent: event.rateLimits.secondary.usedPercent
        ))

        if primarySamples.count > maxSamples {
            primarySamples.removeFirst(primarySamples.count - maxSamples)
        }
        if secondarySamples.count > maxSamples {
            secondarySamples.removeFirst(secondarySamples.count - maxSamples)
        }
    }
}
