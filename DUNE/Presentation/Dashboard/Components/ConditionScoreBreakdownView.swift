import SwiftUI

/// Shows measured/model terms instead of invented weighted component scores.
struct ConditionScoreBreakdownView: View {
    let detail: ConditionScoreDetail?

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Score Components")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                row("HRV (Z-Score)", icon: "waveform.path.ecg", value: detail?.zScore,
                    color: DS.Color.hrv, fractionDigits: 2, identifier: "hrv")
                Divider()
                row("RHR Adjustment", icon: "heart.fill", value: rhrAdjustment,
                    color: DS.Color.rhr, fractionDigits: 1, identifier: "rhr")
                Divider()
                row("Time-of-day Effect", icon: "clock", value: detail?.timeOfDayAdjustment,
                    color: DS.Color.activity, fractionDigits: 1, identifier: "time")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("score-composition-card")
    }

    private var rhrAdjustment: Double? {
        guard let detail, detail.todayRHR != nil, detail.baselineRHR != nil,
              detail.rhrDeltaFromBaseline != nil else { return nil }
        return detail.rhrAdjustment
    }

    private func row(_ title: LocalizedStringKey, icon: String, value: Double?, color: Color,
                     fractionDigits: Int, identifier: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .padding(DS.Spacing.sm)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(value?.formattedWithSeparator(fractionDigits: fractionDigits, alwaysShowSign: true) ?? "—")
                    .font(.title3.bold().monospacedDigit())
                    .accessibilityIdentifier("condition-component-value-\(identifier)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
