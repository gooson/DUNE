import SwiftUI

/// Shared projection data; T04 opts into an accessible phase layout during its rollout.
struct TimeOfDayCard: View {
    let currentAdjustment: Double
    let usesAdaptiveLayout: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let phases: [(title: LocalizedStringKey, projected: Int)]
    private let phaseIcons = ["moon.stars", "sunrise", "sun.max", "sunset"]

    init(currentAdjustment: Double, baseScore: Double, usesAdaptiveLayout: Bool = false) {
        self.currentAdjustment = currentAdjustment
        self.usesAdaptiveLayout = usesAdaptiveLayout
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

                if usesAdaptiveLayout && dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Label(phase.title, systemImage: phaseIcons[index])
                                    .font(.subheadline)
                                Text(phase.projected.formatted())
                                    .font(.title3.bold().monospacedDigit())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("condition-time-phase-\(index)")
                        }
                    }
                } else {
                    HStack {
                        ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                            VStack(spacing: DS.Spacing.xxs) {
                                if usesAdaptiveLayout {
                                    Label(phase.title, systemImage: phaseIcons[index])
                                        .font(.caption2)
                                        .foregroundStyle(DS.Color.textSecondary)
                                } else {
                                    Text(phase.title).font(.caption2).foregroundStyle(.tertiary)
                                }
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
}
