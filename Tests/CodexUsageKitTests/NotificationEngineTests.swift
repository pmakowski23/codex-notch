import CodexUsageKit
import Foundation
import Testing

private struct TestScheduler: NotificationScheduling {
    func schedule(id: String, title: String, body: String) {}
}

@Test
func emitsWindowEndingAndBurnRateNotifications() {
    let engine = NotificationEngine(scheduler: TestScheduler())
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let snapshot = UsageSnapshot(
        updatedAt: now,
        rateLimits: RateLimits(
            primary: WindowUsage(
                usedPercent: 45,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(45 * 60)
            ),
            secondary: WindowUsage(
                usedPercent: 30,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(2 * 24 * 60 * 60)
            ),
            planType: "plus",
            rateLimitReachedType: nil
        ),
        primaryProjection: BurnRateProjection(projectedUsedPercentAtReset: 55, minutesRemaining: 45),
        secondaryProjection: BurnRateProjection(projectedUsedPercentAtReset: 62, minutesRemaining: 4000),
        breakdown: .empty
    )

    let settings = AppSettings(
        notifyMinutesBeforeReset: 60,
        notifyUsedBelowPercent: 60,
        burnRateProjectionBelowPercent: 70
    )

    let decisions = engine.evaluate(snapshot: snapshot, settings: settings, now: now)

    #expect(decisions.contains(where: { $0.rule == .windowEnding && $0.windowName == "5-hour" }))
    #expect(decisions.contains(where: { $0.rule == .burnRate && $0.windowName == "5-hour" }))
}
