import SwiftUI
import WatchKit

/// Center page of SessionPagingView for cardio workouts.
/// Displays real-time distance, pace, heart rate, and calories.
struct CardioMetricsView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.appTheme) private var theme

    @State private var showEndConfirmation = false

    /// Pre-resolved activity info to avoid per-tick pattern matching.
    private var cardioInfo: (type: WorkoutActivityType, icon: String, name: String)? {
        guard case .cardio(let type, _) = workoutManager.workoutMode else { return nil }
        return (type, type.iconName, type.typeName)
    }

    /// Whether the current activity uses floors instead of distance as primary metric.
    private var isStairType: Bool {
        cardioInfo?.type.isStairBased ?? false
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 10 : 1)) { context in
            VStack(spacing: DS.Spacing.md) {
                // Activity type + elapsed time
                headerRow(now: context.date)

                Spacer(minLength: 0)

                // Primary metric: Floors (stair) or Distance (other)
                if isStairType {
                    floorsDisplay
                } else {
                    distanceDisplay
                }

                Spacer(minLength: 0)

                // Secondary metrics: Pace + HR + Calories
                secondaryMetrics

                Spacer(minLength: 0)

                // Pause / End controls
                controlButtons
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout") {
                workoutManager.end()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save and finish this workout?")
        }
    }

    // MARK: - Header

    private func headerRow(now: Date) -> some View {
        HStack {
            if let info = cardioInfo {
                Image(systemName: info.icon)
                    .font(.caption)
                    .foregroundStyle(DS.Color.activity)

                Text(info.name)
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(elapsedTime(at: now))
                .font(DS.Typography.tileSubtitle.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    private func elapsedTime(at now: Date) -> String {
        let elapsed = workoutManager.activeElapsedTime(at: now)
        let mins = Int(elapsed) / 60
        let secs = Int(elapsed) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Primary Metric

    private var floorsDisplay: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text("\(Int(workoutManager.floorsClimbed))")
                .font(.system(.largeTitle, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(DS.Color.positive)
                .contentTransition(.numericText())

            Text("floors")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)
        }
    }

    private var distanceDisplay: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(String(format: "%.2f", workoutManager.distanceKm))
                .font(.system(.largeTitle, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(DS.Color.positive)
                .contentTransition(.numericText())

            Text("km")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Secondary Metrics

    private var secondaryMetrics: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Pace
            metricColumn(
                value: workoutManager.formattedPace,
                unit: "/km",
                icon: "speedometer",
                color: DS.Color.activity
            )

            // Heart Rate
            metricColumn(
                value: workoutManager.heartRate > 0
                    ? "\(Int(workoutManager.heartRate))"
                    : "--",
                unit: "bpm",
                icon: "heart.fill",
                color: theme.metricHeartRate
            )

            if cardioInfo?.type == .walking {
                metricColumn(
                    value: workoutManager.steps > 0
                        ? "\(Int(workoutManager.steps))"
                        : "--",
                    unit: "steps",
                    icon: "figure.walk",
                    color: DS.Color.steps
                )
            }

            // Calories
            metricColumn(
                value: workoutManager.activeCalories > 0
                    ? "\(Int(workoutManager.activeCalories))"
                    : "--",
                unit: "kcal",
                icon: "flame.fill",
                color: DS.Color.caution
            )
        }
    }

    private func metricColumn(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)

            Text(value)
                .font(DS.Typography.tileSubtitle.monospacedDigit())
                .contentTransition(.numericText())

            Text(unit)
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Pause / Resume
            Button {
                if workoutManager.isPaused {
                    workoutManager.resume()
                } else {
                    workoutManager.pause()
                }
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.caution)

            // End
            Button {
                showEndConfirmation = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.negative)
        }
    }
}
