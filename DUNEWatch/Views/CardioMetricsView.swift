import SwiftUI
import WatchKit

/// Center page of SessionPagingView for cardio workouts.
/// Displays real-time distance, pace, heart rate, and calories.
struct CardioMetricsView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.appTheme) private var theme

    @State private var showEndConfirmation = false

    var body: some View {
        TimelineView(.periodic(every: isLuminanceReduced ? 10 : 1)) { context in
            VStack(spacing: DS.Spacing.md) {
                // Activity type + elapsed time
                headerRow(now: context.date)

                Spacer(minLength: 0)

                // Primary metric: Distance
                distanceDisplay

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
            Button("End Workout", role: .destructive) {
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
            activityIcon

            Text(activityName)
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            Spacer()

            Text(elapsedTime(at: now))
                .font(DS.Typography.tileSubtitle.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    private var activityIcon: some View {
        Group {
            if case .cardio(let type, _) = workoutManager.workoutMode {
                Image(systemName: iconName(for: type))
                    .font(.caption)
                    .foregroundStyle(DS.Color.activity)
            }
        }
    }

    private var activityName: String {
        if case .cardio(let type, _) = workoutManager.workoutMode {
            return type.typeName
        }
        return "Cardio"
    }

    private func elapsedTime(at now: Date) -> String {
        guard let start = workoutManager.startDate else { return "0:00" }
        let elapsed = Swift.max(now.timeIntervalSince(start), 0)
        let mins = Int(elapsed) / 60
        let secs = Int(elapsed) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Distance (Primary)

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

    // MARK: - Helpers

    private func iconName(for activityType: WorkoutActivityType) -> String {
        switch activityType {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .hiking: "figure.hiking"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .handCycling: "figure.hand.cycling"
        case .crossCountrySkiing: "figure.skiing.crosscountry"
        case .downhillSkiing: "figure.skiing.downhill"
        case .paddleSports: "oar.2.crossed"
        case .swimBikeRun: "figure.run"
        default: "figure.run"
        }
    }
}
