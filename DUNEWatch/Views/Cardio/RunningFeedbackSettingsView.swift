import SwiftUI

/// Running-only voice feedback preferences, presented from workout controls.
struct RunningFeedbackSettingsView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Toggle("Voice Feedback", isOn: Binding(
                get: { workoutManager.isRunningVoiceFeedbackEnabled },
                set: { workoutManager.setRunningVoiceFeedbackEnabled($0) }
            ))
            .accessibilityIdentifier("watch-running-feedback-enabled-toggle")

            Picker("Feedback Distance", selection: settingsBinding(\.distanceIntervalMeters)) {
                Text("500 m").tag(500.0)
                Text("1 km").tag(1_000.0)
                Text("2 km").tag(2_000.0)
            }
            .accessibilityIdentifier("watch-running-feedback-distance")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text("Feedback Volume")
                    Spacer(minLength: DS.Spacing.xs)
                    Text(workoutManager.runningFeedbackSettings.volume,
                         format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                }
                .font(DS.Typography.metricLabel)

                Slider(value: settingsBinding(\.volume), in: 0...1)
                    .tint(DS.Color.activity)
                    .accessibilityLabel("Feedback Volume")
                    .accessibilityValue(Text(workoutManager.runningFeedbackSettings.volume,
                                             format: .percent.precision(.fractionLength(0))))
                    .accessibilityIdentifier("watch-running-feedback-volume")
            }

            Toggle("Target Pace Alerts", isOn: settingsBinding(\.paceAlertsEnabled))
                .accessibilityIdentifier("watch-running-pace-alerts-toggle")

            if workoutManager.runningFeedbackSettings.paceAlertsEnabled {
                Stepper(value: settingsBinding(\.targetPaceSecondsPerKm), in: 120...1_200, step: 5) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Target Pace")
                            .font(DS.Typography.metricLabel)
                        Text(formattedPace(workoutManager.runningFeedbackSettings.targetPaceSecondsPerKm))
                            .font(DS.Typography.secondaryMetric)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .accessibilityIdentifier("watch-running-target-pace-value")
                    }
                }
                .accessibilityIdentifier("watch-running-target-pace")

                Picker("Pace Tolerance", selection: settingsBinding(\.paceToleranceSecondsPerKm)) {
                    Text("10 s").tag(10.0)
                    Text("15 s").tag(15.0)
                    Text("30 s").tag(30.0)
                    Text("60 s").tag(60.0)
                    if !Self.standardTolerances.contains(workoutManager.runningFeedbackSettings.paceToleranceSecondsPerKm) {
                        let tolerance = workoutManager.runningFeedbackSettings.paceToleranceSecondsPerKm
                        Text(verbatim: "\(tolerance.formatted()) s")
                            .tag(tolerance)
                    }
                }
                .accessibilityIdentifier("watch-running-pace-tolerance")
            }
        }
        .navigationTitle("Voice")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("watch-running-feedback-settings-done")
            }
        }
        .accessibilityIdentifier("watch-running-feedback-settings")
    }

    private func settingsBinding<Value>(
        _ keyPath: WritableKeyPath<RunningFeedbackSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { workoutManager.runningFeedbackSettings[keyPath: keyPath] },
            set: { value in
                var settings = workoutManager.runningFeedbackSettings
                settings[keyPath: keyPath] = value
                workoutManager.updateRunningFeedbackSettings(settings)
            }
        )
    }

    private func formattedPace(_ secondsPerKilometer: Double) -> String {
        let seconds = Int(secondsPerKilometer)
        let minutes = seconds / 60
        let remaining = seconds % 60
        return "\(minutes.formatted()):\(remaining.formatted(.number.precision(.integerLength(2)))) /km"
    }

    private static let standardTolerances: Set<Double> = [10, 15, 30, 60]
}

#Preview("Running feedback settings") {
    RunningFeedbackSettingsView()
        .environment(WorkoutManager.shared)
}
