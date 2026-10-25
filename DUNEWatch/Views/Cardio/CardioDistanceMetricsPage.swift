import SwiftUI

/// Running-only session page with accumulated distance as the primary reading.
struct CardioDistanceMetricsPage: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 10 : 1)) { context in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Distance")
                            .font(DS.Typography.metricLabel)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: DS.Spacing.xs)

                        if workoutManager.isPaused {
                            Text("Paused")
                                .font(DS.Typography.metricLabel)
                                .foregroundStyle(DS.Color.caution)
                                .accessibilityIdentifier("watch-running-paused-indicator")
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(workoutManager.distanceKm, format: .number.precision(.fractionLength(2)))
                            .font(DS.Typography.primaryMetric)
                            .foregroundStyle(DS.Color.activity)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .accessibilityIdentifier("watch-running-distance-value")
                            .accessibilityLabel("Distance")
                            .accessibilityValue(Text(verbatim: "\(workoutManager.distanceKm.formatted(.number.precision(.fractionLength(2)))) km"))

                        Text("km")
                            .font(DS.Typography.metricLabel)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        metric(
                            label: "Elapsed",
                            value: formattedElapsed(at: context.date),
                            identifier: "watch-running-elapsed-value"
                        )

                        metric(
                            label: "Avg Pace",
                            value: formattedAveragePace(at: context.date),
                            unit: "/km",
                            identifier: "watch-running-average-pace-value",
                            accessibilityLabel: "Average Pace"
                        )
                    }

                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text("Heart Rate")
                            .font(DS.Typography.metricLabel)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: DS.Spacing.xs)

                        Text(workoutManager.heartRate > 0 ? Int(workoutManager.heartRate).formatted() : "--")
                            .font(DS.Typography.secondaryMetric)
                            .foregroundStyle(DS.Color.heartRate)
                            .contentTransition(.numericText())
                            .accessibilityIdentifier("watch-running-heart-rate-value")
                            .accessibilityLabel("Heart Rate")
                            .accessibilityValue(Text(verbatim: workoutManager.heartRate > 0
                                ? "\(Int(workoutManager.heartRate)) bpm" : "-- bpm"))

                        Text("bpm")
                            .font(DS.Typography.metricLabel)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityIdentifier("watch-running-distance-metrics")
    }

    private func metric(
        label: LocalizedStringKey,
        value: String,
        unit: LocalizedStringKey? = nil,
        identifier: String,
        accessibilityLabel: LocalizedStringKey? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(DS.Typography.secondaryMetric)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier(identifier)
                    .accessibilityLabel(accessibilityLabel ?? label)
                    .accessibilityValue(Text(value))

                if let unit {
                    Text(unit)
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedElapsed(at date: Date) -> String {
        let seconds = max(0, Int(workoutManager.activeElapsedTime(at: date)))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        let paddedSeconds = remainingSeconds.formatted(.number.precision(.integerLength(2)))

        if minutes >= 60 {
            let hours = minutes / 60
            let paddedMinutes = (minutes % 60).formatted(.number.precision(.integerLength(2)))
            return "\(hours.formatted()):\(paddedMinutes):\(paddedSeconds)"
        }
        return "\(minutes.formatted()):\(paddedSeconds)"
    }

    private func formattedAveragePace(at date: Date) -> String {
        let distance = workoutManager.distanceKm
        guard distance > 0.01 else { return "--:--" }

        let secondsPerKilometer = workoutManager.activeElapsedTime(at: date) / distance
        guard secondsPerKilometer.isFinite, secondsPerKilometer > 0, secondsPerKilometer < 3600 else {
            return "--:--"
        }

        let roundedSeconds = Int(secondsPerKilometer.rounded())
        let minutes = roundedSeconds / 60
        let seconds = roundedSeconds % 60
        return "\(minutes.formatted()):\(seconds.formatted(.number.precision(.integerLength(2))))"
    }
}

#Preview("Running distance") {
    CardioDistanceMetricsPage()
        .environment(WorkoutManager.shared)
}
