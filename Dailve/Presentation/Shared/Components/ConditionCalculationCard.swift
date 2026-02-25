import SwiftUI

/// Reusable card that shows the detailed breakdown of a Condition Score computation.
/// Used in both Dashboard (ConditionScoreDetailView) and Wellness (WellnessScoreDetailView).
struct ConditionCalculationCard: View {
    let detail: ConditionScoreDetail

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "function")
                        .foregroundStyle(.secondary)
                    Text("Condition Calculation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                VStack(spacing: DS.Spacing.sm) {
                    row(
                        label: "Today HRV",
                        value: String(format: "%.1f ms", detail.todayHRV),
                        sub: formatDate(detail.todayDate)
                    )
                    row(
                        label: "Baseline HRV",
                        value: String(format: "%.1f ms", detail.baselineHRV),
                        sub: "\(detail.daysInBaseline) days"
                    )

                    Divider()

                    row(
                        label: "Z-Score",
                        value: String(format: "%+.2f", detail.zScore),
                        sub: zScoreLabel(detail.zScore)
                    )
                    row(
                        label: "StdDev (ln)",
                        value: String(format: "%.3f", detail.stdDev),
                        sub: detail.stdDev < detail.effectiveStdDev
                            ? String(format: "→ floor %.2f", detail.effectiveStdDev)
                            : "natural"
                    )

                    if detail.rhrPenalty > 0 {
                        row(
                            label: "RHR Penalty",
                            value: String(format: "-%.1f", detail.rhrPenalty),
                            sub: ""
                        )
                    }

                    Divider()

                    row(
                        label: "Raw Score",
                        value: String(format: "%.1f", detail.rawScore),
                        sub: "clamped [0–100]"
                    )
                }
            }
        }
    }

    // MARK: - Private

    private func row(label: String, value: String, sub: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()

                if !sub.isEmpty {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func zScoreLabel(_ z: Double) -> String {
        if z > 1.0 { return "well above" }
        if z > 0.5 { return "above avg" }
        if z > -0.5 { return "normal" }
        if z > -1.0 { return "slightly below" }
        if z > -2.0 { return "below avg" }
        return "well below"
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
