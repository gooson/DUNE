import SwiftUI

struct DailyProgressRingCard: View {
    let stepsProgress: Double
    let stepsValue: String
    let sleepProgress: Double
    let sleepValue: String
    let habitProgress: Double?
    let habitValue: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme

    private enum Layout {
        static let ringSize: CGFloat = 48
        static let ringLineWidth: CGFloat = 5
    }

    var body: some View {
        DashboardSupportCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.Color.steps)
                        .frame(width: 38, height: 38)
                        .background(DS.Color.steps.opacity(0.17), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Goals")
                            .font(.headline)
                        Text("Steps and last sleep")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryTextColor)
                    }
                }

                let tiles = progressTiles
                if dynamicTypeSize >= .xxxLarge {
                    VStack(spacing: 9) {
                        tiles
                    }
                } else {
                    HStack(alignment: .top, spacing: 9) {
                        tiles
                    }
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
            identifier: "dashboard-progress-steps"
        )
        progressTile(
            title: "Sleep", progress: sleepProgress, color: DS.Color.sleep,
            icon: "moon.fill", value: sleepValue, goal: "Goal 8 hours",
            identifier: "dashboard-progress-sleep"
        )
        if let habitProgress, let habitValue {
            progressTile(
                title: "Habits", progress: habitProgress, color: DS.Color.activity,
                icon: "checkmark", value: habitValue, goal: "Today's habits",
                identifier: "dashboard-progress-habits"
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
        identifier: String
    ) -> some View {
        let clampedProgress = progress.isFinite ? min(max(progress, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                ZStack {
                    ProgressRingView(
                        progress: clampedProgress,
                        ringColor: color,
                        lineWidth: Layout.ringLineWidth,
                        size: Layout.ringSize
                    )
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                        .accessibilityIdentifier("\(identifier)-name")
                    Text(value)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text(goal)
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(identifier)-goal")
                }
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(color.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .frame(width: geometry.size.width * clampedProgress)
                    }
            }
            .frame(height: 7)
            .accessibilityHidden(true)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme == .desertWarm ? DesertPalette.border : theme.secondaryTextColor.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(Text(clampedProgress, format: .percent.precision(.fractionLength(0))))
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
