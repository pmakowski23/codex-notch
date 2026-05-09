import CodexUsageKit
import SwiftUI

struct TaskBreakdownView: View {
    let breakdown: TaskBreakdownSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Token breakdown (last 5h)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            HStack(alignment: .top, spacing: 12) {
                breakdownSection(
                    title: "Projects",
                    emptyText: "No project token usage yet",
                    buckets: Array(breakdown.fiveHours.projects.prefix(3))
                )

                breakdownSection(
                    title: "Models",
                    emptyText: "No model token usage yet",
                    buckets: Array(breakdown.fiveHours.models.prefix(3))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func breakdownSection(title: String, emptyText: String, buckets: [UsageBucket]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
            if buckets.isEmpty {
                emptyRow(emptyText)
            } else {
                ForEach(buckets) { bucket in
                    row(bucket)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ bucket: UsageBucket) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(simplifiedName(bucket.name))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
            Spacer()
            Text(formattedTokens(bucket.tokens))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.64))
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
            .padding(.vertical, 2)
    }

    private func formattedTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM tok", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.1fk tok", Double(tokens) / 1_000)
        }
        return "\(tokens) tok"
    }

    private func simplifiedName(_ value: String) -> String {
        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value).lastPathComponent
        }
        return value
    }
}
