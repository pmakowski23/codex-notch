import CodexUsageKit
import SwiftUI

struct UsageRingsView: View {
    @Bindable var usageStore: UsageStore

    var body: some View {
        HStack(spacing: 12) {
            ring(
                title: "5-hour window",
                shortTitle: "5h",
                percent: usageStore.latestEvent?.rateLimits.primary.usedPercent ?? 0,
                resetsAt: usageStore.latestEvent?.rateLimits.primary.resetsAt
            )
            ring(
                title: "7-day window",
                shortTitle: "7d",
                percent: usageStore.latestEvent?.rateLimits.secondary.usedPercent ?? 0,
                resetsAt: usageStore.latestEvent?.rateLimits.secondary.resetsAt
            )
        }
    }

    private func ring(title: String, shortTitle: String, percent: Double, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: min(1, max(0, percent / 100)))
                        .stroke(progressColor(for: percent), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(percent.rounded()))%")
                        .font(.caption.bold())
                        .monospacedDigit()
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 2) {
                    Text(shortTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                    Text(timeLeftText(resetsAt))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func progressColor(for percent: Double) -> LinearGradient {
        switch percent {
        case ..<60:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case ..<85:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func timeLeftText(_ resetsAt: Date?) -> String {
        guard let resetsAt else {
            return "reset: -"
        }
        let seconds = max(0, resetsAt.timeIntervalSinceNow)
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        return "reset in \(hours)h \(minutes)m"
    }
}
