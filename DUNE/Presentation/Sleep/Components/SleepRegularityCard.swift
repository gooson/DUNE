import SwiftUI

struct SleepRegularityCard: View {
    let regularity: SleepRegularityIndex?

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Label(String(localized: "Sleep Regularity"), systemImage: "clock.badge.checkmark")
                        .font(.callout)
                        .foregroundStyle(DS.Color.textSecondary)
                    Spacer()
                    if let regularity {
                        Text("\(regularity.score)")
                            .font(.title3.bold())
                            .foregroundStyle(scoreColor(regularity.score))
                    }
                }

                if let regularity {
                    HStack(spacing: DS.Spacing.lg) {
                        statItem(
                            value: formatTime(regularity.averageBedtime),
                            label: String(localized: "Avg Bedtime")
                        )
                        statItem(
                            value: "±\(Int(regularity.bedtimeStdDevMinutes))",
                            unit: String(localized: "min"),
                            label: String(localized: "Variation")
                        )
                        statItem(
                            value: formatTime(regularity.averageWakeTime),
                            label: String(localized: "Avg Wake")
                        )
                    }

                    HStack {
                        confidenceBadge(regularity.confidence)
                        Spacer()
                        Text(String(localized: "\(regularity.dataPointCount) nights"))
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                } else {
                    SleepDataPlaceholder()
                }
            }
        }
        .accessibilityIdentifier("sleep-regularity-card")
    }

    private func statItem(value: String, unit: String = "", label: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func confidenceBadge(_ confidence: SleepRegularityIndex.Confidence) -> some View {
        Text(confidence.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 2)
            .background(confidenceColor(confidence).opacity(DS.Opacity.badge), in: Capsule())
            .foregroundStyle(confidenceColor(confidence))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: DS.Color.sleep
        case 50..<80: .orange
        default: .red
        }
    }

    private func confidenceColor(_ confidence: SleepRegularityIndex.Confidence) -> Color {
        switch confidence {
        case .low: .gray
        case .medium: .orange
        case .high: DS.Color.sleep
        }
    }

    private func formatTime(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
