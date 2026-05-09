import Foundation
import Observation

public struct AppSettings: Codable, Equatable, Sendable {
    public var notifyMinutesBeforeReset: Int
    public var notifyUsedBelowPercent: Double
    public var burnRateProjectionBelowPercent: Double
    public var pauseNotificationsUntil: Date?
    public var sessionsRootPath: String
    public var stateDatabasePath: String

    public init(
        notifyMinutesBeforeReset: Int = 60,
        notifyUsedBelowPercent: Double = 60,
        burnRateProjectionBelowPercent: Double = 70,
        pauseNotificationsUntil: Date? = nil,
        sessionsRootPath: String = "~/.codex/sessions",
        stateDatabasePath: String = "~/.codex/state_5.sqlite"
    ) {
        self.notifyMinutesBeforeReset = notifyMinutesBeforeReset
        self.notifyUsedBelowPercent = notifyUsedBelowPercent
        self.burnRateProjectionBelowPercent = burnRateProjectionBelowPercent
        self.pauseNotificationsUntil = pauseNotificationsUntil
        self.sessionsRootPath = sessionsRootPath
        self.stateDatabasePath = stateDatabasePath
    }

    public var resolvedSessionsRoot: URL {
        URL(fileURLWithPath: NSString(string: sessionsRootPath).expandingTildeInPath)
    }

    public var resolvedStateDatabasePath: String {
        NSString(string: stateDatabasePath).expandingTildeInPath
    }
}

@MainActor
@Observable
public final class SettingsStore {
    public var settings: AppSettings {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key = "app.codexusage.settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? decoder.decode(AppSettings.self, from: data)
        {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    private func save() {
        guard let data = try? encoder.encode(settings) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
