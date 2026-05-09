import CodexUsageKit
import AppKit
import SwiftUI
#if canImport(DynamicNotchKit)
import DynamicNotchKit
#endif

private enum NotchPanelMode {
    case collapsed
    case hovered
    case expanded
}

private struct NotchGeometry {
    let width: CGFloat
    let height: CGFloat

    static let fallback = NotchGeometry(width: 190, height: 32)

    static var current: NotchGeometry {
        guard let screen = NSScreen.main else {
            return fallback
        }

        let notchHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : fallback.height
        let notchWidth: CGFloat
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            let inferredWidth = screen.frame.width - leftArea.width - rightArea.width
            notchWidth = inferredWidth > 0 ? inferredWidth : fallback.width
        } else {
            notchWidth = fallback.width
        }

        return NotchGeometry(width: notchWidth, height: notchHeight)
    }
}

@MainActor
final class NotchPanel {
    private let usageStore: UsageStore
    private let settingsStore: SettingsStore
    private var fallbackPanel: NSPanel?
    private var settingsPanel: NSPanel?
    private var mode: NotchPanelMode = .collapsed
    private var globalEventMonitor: Any?

    #if canImport(DynamicNotchKit)
    private lazy var notch = DynamicNotch {
        NotchContentView(usageStore: usageStore, settingsStore: settingsStore)
    }
    #endif

    init(usageStore: UsageStore, settingsStore: SettingsStore) {
        self.usageStore = usageStore
        self.settingsStore = settingsStore
    }

    func showCollapsed() {
        #if canImport(DynamicNotchKit)
        #else
        if fallbackPanel == nil {
            createFallbackPanelIfNeeded()
        }
        setMode(.collapsed, animated: false)
        stopGlobalMonitor()
        fallbackPanel?.orderFrontRegardless()
        #endif
    }

    func present() {
        #if canImport(DynamicNotchKit)
        Task {
            await notch.expand()
        }
        #else
        if fallbackPanel == nil {
            createFallbackPanelIfNeeded()
        }
        setMode(mode == .expanded ? .collapsed : .expanded, animated: true)
        fallbackPanel?.orderFrontRegardless()
        #endif
    }

    private func setMode(_ nextMode: NotchPanelMode, animated: Bool) {
        guard mode != nextMode else {
            return
        }
        mode = nextMode
        guard let panel = fallbackPanel,
              let hosting = panel.contentView as? NSHostingView<NotchRootView>
        else {
            return
        }

        hosting.rootView = makeRootView()
        let size = panelSize(for: nextMode)
        let origin = panelOrigin(for: size)
        let newFrame = NSRect(origin: origin, size: size)
        if animated {
            panel.animator().setFrame(newFrame, display: true)
        } else {
            panel.setFrame(newFrame, display: true)
        }

        if nextMode == .expanded {
            startGlobalMonitor()
        } else {
            stopGlobalMonitor()
        }
    }

    private func createFallbackPanelIfNeeded() {
        let size = panelSize(for: .collapsed)
        let frame = NSRect(origin: panelOrigin(for: size), size: size)
        let hosting = NSHostingView(rootView: makeRootView())
        hosting.frame = frame

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.ignoresMouseEvents = false

        fallbackPanel = panel
        panel.orderFrontRegardless()
    }

    private func panelSize(for mode: NotchPanelMode) -> NSSize {
        let notch = NotchGeometry.current
        switch mode {
        case .collapsed:
            return NSSize(width: notch.width + 10, height: notch.height + 8)
        case .hovered:
            return NSSize(width: notch.width + 16, height: 90)
        case .expanded:
            return NSSize(width: 440, height: 256)
        }
    }

    private func panelOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint(x: 300, y: 900)
        }
        let frame = screen.frame
        let visible = screen.visibleFrame

        let x = frame.midX - (size.width / 2)
        let y: CGFloat
        switch mode {
        case .expanded:
            // Keep full content visible below menu bar/notch.
            y = visible.maxY - size.height - 8
        case .collapsed:
            // Align compact island flush to the top of the screen.
            y = frame.maxY - size.height
        case .hovered:
            // Keep the top edge under the pointer when expanding from the screen edge.
            y = frame.maxY - size.height
        }
        return NSPoint(x: x, y: y)
    }

    private func makeRootView() -> NotchRootView {
        NotchRootView(
            usageStore: usageStore,
            settingsStore: settingsStore,
            mode: mode,
            onHoverChanged: { [weak self] isHovering in
                guard let self else { return }
                guard self.mode != .expanded else { return }
                self.setMode(isHovering ? .hovered : .collapsed, animated: true)
            },
            onToggleExpanded: { [weak self] in
                guard let self else { return }
                self.setMode(self.mode == .expanded ? .collapsed : .expanded, animated: true)
            },
            onSettings: { [weak self] in
                guard let self else { return }
                self.setMode(.collapsed, animated: true)
                self.presentSettingsPanel()
            },
            onMinimize: { [weak self] in
                self?.setMode(.collapsed, animated: true)
            }
        )
    }

    private func startGlobalMonitor() {
        guard globalEventMonitor == nil else {
            return
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.mode == .expanded else { return }
            if event.type == .keyDown, event.keyCode == 53 {
                DispatchQueue.main.async {
                    self.setMode(.collapsed, animated: true)
                }
                return
            }
            guard let panel = self.fallbackPanel else { return }
            let location = NSEvent.mouseLocation
            if !panel.frame.contains(location) {
                DispatchQueue.main.async {
                    self.setMode(.collapsed, animated: true)
                }
            }
        }
    }

    private func stopGlobalMonitor() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }

    private func presentSettingsPanel() {
        if settingsPanel == nil {
            let root = SettingsModalView(settingsStore: settingsStore) { [weak self] in
                self?.settingsPanel?.close()
            }
            let hosting = NSHostingView(rootView: root)
            hosting.frame = NSRect(x: 0, y: 0, width: 420, height: 316)

            let panel = NSPanel(
                contentRect: hosting.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.contentView = hosting
            panel.backgroundColor = .clear
            panel.isMovableByWindowBackground = true
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.center()
            settingsPanel = panel
        }
        settingsPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct NotchSilhouette: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()

        return path
    }
}

private struct NotchRootView: View {
    @Bindable var usageStore: UsageStore
    @Bindable var settingsStore: SettingsStore
    let mode: NotchPanelMode
    let onHoverChanged: (Bool) -> Void
    let onToggleExpanded: () -> Void
    let onSettings: () -> Void
    let onMinimize: () -> Void

    var body: some View {
        Group {
            switch mode {
            case .collapsed:
                collapsedView
            case .hovered:
                hoveredView
            case .expanded:
                expandedView
            }
        }
    }

    private var collapsedView: some View {
        NotchSilhouette(cornerRadius: 15)
            .fill(Color.black.opacity(0.92))
            .overlay(
                HStack(spacing: 8) {
                    Image(systemName: "capsule.portrait.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Codex")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(.horizontal, 12)
            )
            .overlay(
                NotchSilhouette(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .cyan.opacity(0.12), .white.opacity(0.06)],
                            startPoint: .bottomLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .onHover { inside in
                onHoverChanged(inside)
            }
            .onTapGesture {
                onToggleExpanded()
            }
    }

    private var hoveredView: some View {
        NotchSilhouette(cornerRadius: 18)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.96),
                        Color(red: 0.05, green: 0.07, blue: 0.11).opacity(0.95),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("Codex")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                        Text(lastUpdateText)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .layoutPriority(1)
                    }
                    HStack(spacing: 7) {
                        compactUsagePill("5h", usageStore.latestEvent?.rateLimits.primary.usedPercent ?? 0)
                        compactUsagePill("7d", usageStore.latestEvent?.rateLimits.secondary.usedPercent ?? 0)
                    }
                }
                .padding(8)
            }
            .overlay(
                NotchSilhouette(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .cyan.opacity(0.11), .white.opacity(0.06)],
                            startPoint: .bottomLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .onHover { inside in
                onHoverChanged(inside)
            }
            .onTapGesture {
                onToggleExpanded()
            }
    }

    private func compactUsagePill(_ label: String, _ percent: Double) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: min(1, max(0, percent / 100)))
                    .stroke(hoverProgressColor(for: percent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 14, height: 14)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(Int(percent.rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        )
    }

    private func hoverProgressColor(for percent: Double) -> LinearGradient {
        switch percent {
        case ..<60:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case ..<85:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var expandedView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.97),
                            Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.95),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .cyan.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    header
                    HStack(spacing: 8) {
                        Button {
                            onSettings()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(6)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onToggleExpanded()
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(6)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                UsageRingsView(usageStore: usageStore)
                TaskBreakdownView(breakdown: usageStore.breakdown)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .compositingGroup()
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex Usage")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                    Text(planText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            Spacer()
            Text(lastUpdateText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private var planText: String {
        if let plan = usageStore.latestEvent?.rateLimits.planType, !plan.isEmpty {
            return "\(plan.capitalized) plan"
        }
        return "Local usage monitor"
    }

    private var lastUpdateText: String {
        guard let date = usageStore.latestEvent?.eventTimestamp else {
            return "Waiting for data"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

private struct SettingsModalView: View {
    @Bindable var settingsStore: SettingsStore
    let onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.98),
                    Color(red: 0.04, green: 0.06, blue: 0.10),
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.cyan.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 44)
                .offset(x: -170, y: -132)

            Circle()
                .fill(.blue.opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: 170, y: 130)

            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(spacing: 10) {
                    settingControl(
                        icon: "timer",
                        title: "Window ending",
                        subtitle: "Notify before a usage window resets.",
                        suffix: "min",
                        value: $settingsStore.settings.notifyMinutesBeforeReset,
                        range: 5...240
                    )

                    settingControl(
                        icon: "bell.badge",
                        title: "Used below",
                        subtitle: "Only alert while current usage is still low.",
                        suffix: "%",
                        value: Binding(
                            get: { Int(settingsStore.settings.notifyUsedBelowPercent) },
                            set: { settingsStore.settings.notifyUsedBelowPercent = Double($0) }
                        ),
                        range: 5...95
                    )

                    settingControl(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Projected below",
                        subtitle: "Warn when burn rate is on track to stay under budget.",
                        suffix: "%",
                        value: Binding(
                            get: { Int(settingsStore.settings.burnRateProjectionBelowPercent) },
                            set: { settingsStore.settings.burnRateProjectionBelowPercent = Double($0) }
                        ),
                        range: 5...95
                    )
                }
            }
            .padding(22)
        }
        .frame(width: 420, height: 316)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .cyan.opacity(0.16), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )

                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Notification Settings")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.96))
                Text("Tune when Codex usage nudges should appear.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.66))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close settings")
        }
    }

    private func settingControl(
        icon: String,
        title: String,
        subtitle: String,
        suffix: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.cyan.opacity(0.88))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(value.wrappedValue) \(suffix)")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white.opacity(0.94))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.10))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )

            Stepper("", value: value, in: range, step: 5)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 68)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.11), lineWidth: 1)
        )
    }
}
