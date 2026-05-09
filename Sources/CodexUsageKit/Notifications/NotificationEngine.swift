import Foundation
import UserNotifications

public enum NotificationRule: String, Sendable {
    case windowEnding
    case burnRate
}

public struct NotificationDecision: Equatable, Hashable, Sendable {
    public let rule: NotificationRule
    public let windowName: String
    public let resetAt: Date
    public let title: String
    public let body: String

    public init(
        rule: NotificationRule,
        windowName: String,
        resetAt: Date,
        title: String,
        body: String
    ) {
        self.rule = rule
        self.windowName = windowName
        self.resetAt = resetAt
        self.title = title
        self.body = body
    }
}

public protocol NotificationScheduling: Sendable {
    func schedule(id: String, title: String, body: String)
}

public struct UserNotificationScheduler: NotificationScheduling {
    public init() {}

    public func schedule(id: String, title: String, body: String) {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

public final class NotificationEngine: @unchecked Sendable {
    private var sentKeys: Set<String> = []
    private let scheduler: NotificationScheduling

    public init(scheduler: NotificationScheduling = UserNotificationScheduler()) {
        self.scheduler = scheduler
    }

    public func evaluate(
        snapshot: UsageSnapshot,
        settings: AppSettings,
        now: Date = Date()
    ) -> [NotificationDecision] {
        guard shouldNotify(settings: settings, now: now) else {
            return []
        }

        var output: [NotificationDecision] = []
        output.append(contentsOf: evaluateWindowEnding(snapshot: snapshot, settings: settings, now: now))
        output.append(contentsOf: evaluateBurnRate(snapshot: snapshot, settings: settings))
        return output.filter { decision in
            let key = dedupeKey(for: decision)
            return !sentKeys.contains(key)
        }
    }

    public func fire(_ decisions: [NotificationDecision]) {
        for decision in decisions {
            let key = dedupeKey(for: decision)
            guard !sentKeys.contains(key) else { continue }
            sentKeys.insert(key)
            scheduler.schedule(id: key, title: decision.title, body: decision.body)
        }
    }

    private func evaluateWindowEnding(
        snapshot: UsageSnapshot,
        settings: AppSettings,
        now: Date
    ) -> [NotificationDecision] {
        let windows = [
            ("5-hour", snapshot.rateLimits.primary),
            ("weekly", snapshot.rateLimits.secondary),
        ]

        return windows.compactMap { pair in
            let (name, usage) = pair
            let minutesLeft = usage.resetsAt.timeIntervalSince(now) / 60
            guard minutesLeft <= Double(settings.notifyMinutesBeforeReset) else {
                return nil
            }
            guard usage.usedPercent < settings.notifyUsedBelowPercent else {
                return nil
            }
            return NotificationDecision(
                rule: .windowEnding,
                windowName: name,
                resetAt: usage.resetsAt,
                title: "Codex usage reminder (\(name))",
                body: "Window resets in \(Int(max(0, minutesLeft))) min and you're at \(Int(usage.usedPercent))%."
            )
        }
    }

    private func evaluateBurnRate(
        snapshot: UsageSnapshot,
        settings: AppSettings
    ) -> [NotificationDecision] {
        let windows: [(String, Date, BurnRateProjection?)] = [
            ("5-hour", snapshot.rateLimits.primary.resetsAt, snapshot.primaryProjection),
            ("weekly", snapshot.rateLimits.secondary.resetsAt, snapshot.secondaryProjection),
        ]

        return windows.compactMap { pair in
            let (name, resetAt, projection) = pair
            guard let projection else {
                return nil
            }
            guard projection.projectedUsedPercentAtReset < settings.burnRateProjectionBelowPercent else {
                return nil
            }
            return NotificationDecision(
                rule: .burnRate,
                windowName: name,
                resetAt: resetAt,
                title: "Codex burn-rate is low (\(name))",
                body: "Projected usage at reset is \(Int(projection.projectedUsedPercentAtReset))%."
            )
        }
    }

    private func shouldNotify(settings: AppSettings, now: Date) -> Bool {
        guard let pauseUntil = settings.pauseNotificationsUntil else {
            return true
        }
        return pauseUntil <= now
    }

    private func dedupeKey(for decision: NotificationDecision) -> String {
        "\(decision.rule.rawValue)-\(decision.windowName)-\(Int(decision.resetAt.timeIntervalSince1970))"
    }
}
