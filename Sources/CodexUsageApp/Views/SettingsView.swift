import CodexUsageKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            VStack(alignment: .leading, spacing: 7) {
                settingRow(
                    title: "Window ending threshold",
                    valueText: "\(settingsStore.settings.notifyMinutesBeforeReset) min"
                )
                Stepper(
                    "",
                    value: $settingsStore.settings.notifyMinutesBeforeReset,
                    in: 5...240,
                    step: 5
                )
                .labelsHidden()

                settingRow(
                    title: "Used below",
                    valueText: "\(Int(settingsStore.settings.notifyUsedBelowPercent))%"
                )
                Stepper(
                    "",
                    value: $settingsStore.settings.notifyUsedBelowPercent,
                    in: 5...95,
                    step: 5
                )
                .labelsHidden()

                settingRow(
                    title: "Projected usage below",
                    valueText: "\(Int(settingsStore.settings.burnRateProjectionBelowPercent))%"
                )
                Stepper(
                    "",
                    value: $settingsStore.settings.burnRateProjectionBelowPercent,
                    in: 5...95,
                    step: 5
                )
                .labelsHidden()
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

    private func settingRow(title: String, valueText: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
            Spacer()
            Text(valueText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
        }
    }
}
