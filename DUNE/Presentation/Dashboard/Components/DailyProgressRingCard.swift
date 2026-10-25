import SwiftUI

struct DailyProgressRingCard: View {
    let stepsProgress: Double
    let stepsValue: String
    let sleepProgress: Double
    let sleepValue: String
    let habitProgress: Double?
    let habitValue: String?
    let stepsAvailable: Bool
    let sleepAvailable: Bool

    init(
        stepsProgress: Double,
        stepsValue: String,
        sleepProgress: Double,
        sleepValue: String,
        habitProgress: Double?,
        habitValue: String?,
        stepsAvailable: Bool = true,
        sleepAvailable: Bool = true
    ) {
        self.stepsProgress = stepsProgress
        self.stepsValue = stepsValue
        self.sleepProgress = sleepProgress
        self.sleepValue = sleepValue
        self.habitProgress = habitProgress
        self.habitValue = habitValue
        self.stepsAvailable = stepsAvailable
        self.sleepAvailable = sleepAvailable
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme

    var body: some View {
        DashboardSupportCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Goals")
                        .font(.headline)
                    Text("Steps and last sleep")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                }

                if dynamicTypeSize >= .xxLarge || habitProgress != nil {
                    VStack(spacing: 12) { progressTiles }
                } else {
                    HStack(alignment: .top, spacing: 12) { progressTiles }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard-daily-progress")
    }

    @ViewBuilder
    private var progressTiles: some View {
        progressTile(
            title: "Steps", progress: stepsProgress, color: DS.Color.steps,
            icon: "figure.walk", value: stepsValue, goal: "Goal 10,000",
            identifier: "dashboard-progress-steps", available: stepsAvailable
        )
        progressTile(
            title: "Sleep", progress: sleepProgress, color: DS.Color.sleep,
            icon: "moon.fill", value: sleepValue, goal: "Goal 8 hours",
            identifier: "dashboard-progress-sleep", available: sleepAvailable
        )
        if let habitProgress, let habitValue {
            progressTile(
                title: "Habits", progress: habitProgress, color: DS.Color.activity,
                icon: "checkmark", value: habitValue, goal: "Today's habits",
                identifier: "dashboard-progress-habits", available: true
            )
        }
    }

    private func progressTile(
        title: LocalizedStringKey,
        progress: Double,
        color: Color,
        icon: String,
        value: String,
        goal: LocalizedStringKey,
        identifier: String,
        available: Bool
    ) -> some View {
        let clampedProgress = progress.isFinite ? min(max(progress, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.secondaryTextColor)
                        .accessibilityIdentifier("\(identifier)-name")
                    Text(value)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Text(goal)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(identifier)-goal")
                }
            }

            if available {
                GeometryReader { geometry in
                    Capsule()
                        .fill(color.opacity(0.18))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(color)
                                .frame(width: geometry.size.width * clampedProgress)
                        }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityValue(
            available
                ? Text(clampedProgress, format: .percent.precision(.fractionLength(0)))
                : Text(value)
        )
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    DailyProgressRingCard(
        stepsProgress: 0.66, stepsValue: "6,600", sleepProgress: 0.99,
        sleepValue: "7h 54m", habitProgress: nil, habitValue: nil
    )
    .padding()
}
