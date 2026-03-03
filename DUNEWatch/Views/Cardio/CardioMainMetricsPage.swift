import SwiftUI
import WatchKit

/// Page 1: Primary cardio metrics — elapsed time, distance/pace, HR, calories.
/// Layout adapts based on CardioMetricProfile (running shows pace, cycling shows speed).
struct CardioMainMetricsPage: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.appTheme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 10 : 1)) { context in
            VStack(spacing: DS.Spacing.sm) {
                // Activity type header
                activityHeader

                // Elapsed time (large)
                elapsedTimeDisplay(now: context.date)

                Spacer(minLength: 0)

                // Distance + Pace/Speed (medium 2-col)
                if profile.showsDistance {
                    distanceRow
                }

                Spacer(minLength: 0)

                // HR + Calories (compact 2-col)
                bottomRow
            }
            .padding(.horizontal, DS.Spacing.sm)
        }
    }

    // MARK: - Profile

    private var profile: CardioMetricProfile {
        guard case .cardio(let type, _) = workoutManager.workoutMode else {
            return .generic
        }
        return CardioMetricProfile.profile(for: type)
    }

    // MARK: - Activity Header

    private var activityHeader: some View {
        HStack(spacing: DS.Spacing.xxs) {
            if case .cardio(let type, _) = workoutManager.workoutMode {
                Image(systemName: type.iconName)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.activity)

                Text(type.typeName)
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Elapsed Time

    private func elapsedTimeDisplay(now: Date) -> some View {
        let elapsed = workoutManager.activeElapsedTime(at: now)
        let hours = Int(elapsed) / 3600
        let mins = (Int(elapsed) % 3600) / 60
        let secs = Int(elapsed) % 60

        return Text(hours > 0
            ? String(format: "%d:%02d:%02d", hours, mins, secs)
            : String(format: "%d:%02d", mins, secs)
        )
        .font(DS.Typography.primaryMetric)
        .foregroundStyle(DS.Color.activity)
        .contentTransition(.numericText())
    }

    // MARK: - Distance Row

    private var distanceRow: some View {
        HStack(spacing: DS.Spacing.md) {
            // Distance
            VStack(spacing: DS.Spacing.xxs) {
                Text(String(format: "%.2f", workoutManager.distanceKm))
                    .font(DS.Typography.secondaryMetric)
                    .contentTransition(.numericText())

                Text("km")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)

            // Pace or Speed
            if profile.showsPace {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(workoutManager.formattedPace)
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("/km")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            } else if profile.showsSpeed {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(formattedSpeed)
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("km/h")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Current speed in km/h derived from pace (seconds/km).
    private var formattedSpeed: String {
        let pace = workoutManager.currentPace
        guard pace > 0, pace.isFinite, pace < 3600 else { return "--" }
        let speedKmh = 3600.0 / pace
        return String(format: "%.1f", speedKmh)
    }

    // MARK: - Bottom Row (HR + Calories)

    private var bottomRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Heart Rate
            WorkoutMetricCard(
                icon: "heart.fill",
                value: workoutManager.heartRate > 0
                    ? "\(Int(workoutManager.heartRate))"
                    : "--",
                unit: "bpm",
                color: workoutManager.currentZone?.color ?? theme.metricHeartRate,
                size: .compact
            )

            // Calories
            WorkoutMetricCard(
                icon: "flame.fill",
                value: workoutManager.activeCalories > 0
                    ? "\(Int(workoutManager.activeCalories))"
                    : "--",
                unit: "kcal",
                color: DS.Color.caution,
                size: .compact
            )
        }
    }
}
