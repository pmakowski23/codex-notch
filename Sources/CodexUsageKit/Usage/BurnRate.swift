import Foundation

public struct BurnRateSample: Equatable, Sendable {
    public let timestamp: Date
    public let usedPercent: Double

    public init(timestamp: Date, usedPercent: Double) {
        self.timestamp = timestamp
        self.usedPercent = usedPercent
    }
}

public struct BurnRateProjection: Equatable, Sendable {
    public let projectedUsedPercentAtReset: Double
    public let minutesRemaining: Double

    public init(projectedUsedPercentAtReset: Double, minutesRemaining: Double) {
        self.projectedUsedPercentAtReset = projectedUsedPercentAtReset
        self.minutesRemaining = minutesRemaining
    }
}

public enum BurnRate {
    public static func project(
        samples: [BurnRateSample],
        currentWindow: WindowUsage,
        now: Date
    ) -> BurnRateProjection? {
        guard samples.count >= 2 else {
            return nil
        }

        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard let first = sorted.first, let last = sorted.last else {
            return nil
        }

        let minutesDelta = last.timestamp.timeIntervalSince(first.timestamp) / 60.0
        guard minutesDelta > 0 else {
            return nil
        }

        let percentDelta = last.usedPercent - first.usedPercent
        let percentPerMinute = percentDelta / minutesDelta
        let minutesRemaining = max(0, currentWindow.resetsAt.timeIntervalSince(now) / 60.0)
        let projected = currentWindow.usedPercent + (percentPerMinute * minutesRemaining)
        let clamped = min(100, max(0, projected))

        return BurnRateProjection(
            projectedUsedPercentAtReset: clamped,
            minutesRemaining: minutesRemaining
        )
    }
}
