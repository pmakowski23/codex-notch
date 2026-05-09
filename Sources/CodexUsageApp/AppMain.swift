import AppKit
import CodexUsageKit
import SwiftUI
import UserNotifications

@main
struct CodexUsageAppMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let usageStore = UsageStore()
    private let settingsStore = SettingsStore()
    private let notificationEngine = NotificationEngine()

    private var repository: TasksRepository?
    private var watcher: RolloutWatcher?
    private var notchPanel: NotchPanel?
    private var menuBarController: MenuBarController?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestNotificationAuthorization()

        do {
            repository = try TasksRepository(databasePath: settingsStore.settings.resolvedStateDatabasePath)
        } catch {
            repository = nil
        }

        let panel = NotchPanel(usageStore: usageStore, settingsStore: settingsStore)
        notchPanel = panel
        menuBarController = MenuBarController(onTap: { [weak panel] in
            panel?.present()
        })

        let watcher = RolloutWatcher(sessionsRoot: settingsStore.settings.resolvedSessionsRoot)
        watcher.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event: event)
            }
        }
        self.watcher = watcher
        watcher.start()

        // Keep a compact notch island always visible.
        panel.showCollapsed()

        refreshBreakdown()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBreakdown()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
        refreshTimer?.invalidate()
    }

    private func handle(event: TokenCountEvent) {
        usageStore.apply(event: event)
        refreshBreakdown()
        menuBarController?.update(maxPercent: max(
            event.rateLimits.primary.usedPercent,
            event.rateLimits.secondary.usedPercent
        ))

        guard let snapshot = usageStore.makeSnapshot() else {
            return
        }
        let decisions = notificationEngine.evaluate(
            snapshot: snapshot,
            settings: settingsStore.settings
        )
        notificationEngine.fire(decisions)
    }

    private func refreshBreakdown() {
        guard let repository else {
            return
        }
        if let breakdown = try? repository.fetchBreakdown() {
            usageStore.updateBreakdown(breakdown)
        }
    }

    private func requestNotificationAuthorization() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
