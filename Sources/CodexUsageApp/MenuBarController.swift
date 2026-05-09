import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onTap: () -> Void
    private let showItem = NSMenuItem(title: "Show Codex Usage", action: #selector(didTapStatusItem), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit Codex Usage", action: #selector(didTapQuit), keyEquivalent: "q")

    init(onTap: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onTap = onTap
        super.init()

        let menu = NSMenu()
        showItem.target = self
        quitItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu

        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "Codex Usage")
            icon?.isTemplate = true
            button.image = icon ?? NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Codex Usage")
            button.imagePosition = .imageLeading
            button.title = "Codex"
            button.toolTip = "Codex Usage"
        }
        statusItem.isVisible = true
    }

    func update(maxPercent: Double) {
        statusItem.button?.title = "\(Int(maxPercent.rounded()))%"
    }

    @objc
    private func didTapStatusItem() {
        onTap()
    }

    @objc
    private func didTapQuit() {
        NSApp.terminate(nil)
    }
}
