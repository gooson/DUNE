import SwiftUI

struct YesterdayRecapCard: View {
    let workoutSummary: String?
    let sleepMinutes: Double?
    let yesterdayScore: Int?
    let todayScore: Int?

    var body: some View {
        let hasContent = workoutSummary != nil || sleepMinutes != nil || scoreDelta != nil
        if hasContent {
            InlineCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text("Yesterday")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: DS.Spacing.md) {
                        if let summary = workoutSummary {
                            summaryChip(icon: "figure.run", text: summary)
                        } else {
                            summaryChip(icon: "figure.mind.and.body", text: String(localized: "Rest day"))
                        }

                        if let minutes = sleepMinutes, minutes > 0 {
                            summaryChip(icon: "bed.double.fill", text: formatSleep(minutes))
                        }
                    }

                    if let delta = scoreDelta {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(conditionTransitionText)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)

                            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(delta > 0 ? DS.Color.positive : delta < 0 ? DS.Color.negative : DS.Color.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("dashboard-yesterday-recap")
        }
    }

    private var scoreDelta: Int? {
        guard let y = yesterdayScore, let t = todayScore else { return nil }
        return t - y
    }

    private var conditionTransitionText: String {
        guard let y = yesterdayScore, let t = todayScore else { return "" }
        return String(localized: "Condition \(y) → \(t)")
    }

    private func summaryChip(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(DS.Color.textSecondary)

            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    private func formatSleep(_ minutes: Double) -> String {
        let total = Int(max(0, min(minutes, 1440)))
        let h = total / 60
        let m = total % 60
        if h > 0, m > 0 { return String(localized: "\(h)h \(m)m sleep") }
        if h > 0 { return String(localized: "\(h)h sleep") }
        return String(localized: "\(m)m sleep")
    }
}
