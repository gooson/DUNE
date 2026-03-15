import SwiftUI

/// Shared time-of-day effect card for score detail views.
/// Shows how the score adjusts across 4 time phases (Night/Morning/Noon/Evening).
struct TimeOfDayCard: View {
    let currentAdjustment: Double

    private let phases: [(title: LocalizedStringKey, projected: Int)]

    init(currentAdjustment: Double, baseScore: Double) {
        self.currentAdjustment = currentAdjustment
        let calendar = Calendar.current
        let now = Date()
        self.phases = [(LocalizedStringKey("Night"), 2),
                       (LocalizedStringKey("Morning"), 8),
                       (LocalizedStringKey("Noon"), 13),
                       (LocalizedStringKey("Evening"), 19)].map { title, hour in
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            let adjustment = ScoreTimeOfDayAdjustment.readinessAndWellness(for: date)
            let projected = Int(max(0, min(100, (baseScore + adjustment).rounded())))
            return (title: title, projected: projected)
        }
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Time-of-day Effect")
                    .font(.subheadline.weight(.semibold))

                Text("Current adjustment \(currentAdjustment.formattedWithSeparator(fractionDigits: 0, alwaysShowSign: true))")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                HStack {
                    ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                        VStack(spacing: DS.Spacing.xxs) {
                            Text(phase.title)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("\(phase.projected)")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
