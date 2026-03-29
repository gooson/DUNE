import SwiftUI

struct DailyProgressRingCard: View {
    let stepsProgress: Double  // 0.0...1.0+
    let stepsValue: String
    let sleepProgress: Double
    let sleepValue: String
    let habitProgress: Double?  // nil when no habits configured
    let habitValue: String?

    private enum Layout {
        static let ringSize: CGFloat = 48
        static let ringLineWidth: CGFloat = 6
    }

    var body: some View {
        InlineCard {
            HStack(spacing: DS.Spacing.xl) {
                ringItem(
                    progress: stepsProgress,
                    color: DS.Color.steps,
                    icon: "figure.walk",
                    value: stepsValue,
                    identifier: "dashboard-progress-steps"
                )

                ringItem(
                    progress: sleepProgress,
                    color: DS.Color.sleep,
                    icon: "bed.double.fill",
                    value: sleepValue,
                    identifier: "dashboard-progress-sleep"
                )

                if let habitProgress, let habitValue {
                    ringItem(
                        progress: habitProgress,
                        color: DS.Color.activity,
                        icon: "checkmark.circle.fill",
                        value: habitValue,
                        identifier: "dashboard-progress-habits"
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("dashboard-daily-progress")
    }

    private func ringItem(
        progress: Double,
        color: Color,
        icon: String,
        value: String,
        identifier: String
    ) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                ProgressRingView(
                    progress: min(progress, 1.0),
                    ringColor: color,
                    lineWidth: Layout.ringLineWidth,
                    size: Layout.ringSize
                )

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
                .monospacedDigit()
        }
        .accessibilityIdentifier(identifier)
    }
}
