import SwiftUI

/// Shared time-of-day effect card for score detail views.
/// Shows how the score adjusts across 4 time phases (Night/Morning/Noon/Evening).
struct TimeOfDayCard: View {
    let currentAdjustment: Double
    let baseScore: Double

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Time-of-day Effect")
                    .font(.subheadline.weight(.semibold))

                Text("Current adjustment \(currentAdjustment.formattedWithSeparator(fractionDigits: 0, alwaysShowSign: true))")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                HStack {
                    phaseChip("Night", hour: 2)
                    phaseChip("Morning", hour: 8)
                    phaseChip("Noon", hour: 13)
                    phaseChip("Evening", hour: 19)
                }
            }
        }
    }

    private func phaseChip(_ title: LocalizedStringKey, hour: Int) -> some View {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        let adjustment = ScoreTimeOfDayAdjustment.readinessAndWellness(for: date)
        let projected = Int(max(0, min(100, (baseScore + adjustment).rounded())))

        return VStack(spacing: DS.Spacing.xxs) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("\(projected)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
