import ActivityKit
import SwiftUI
import WidgetKit

struct WatchWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WatchWorkoutAttributes.self) { context in
            WatchWorkoutActivityContent(state: context.state,
                                        isStale: context.isStale)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Workout", systemImage: "figure.run")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale {
                        WorkoutElapsedTime(state: context.state)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                        WatchWorkoutStatus(state: context.state, isStale: context.isStale)
                        if !context.isStale {
                            WatchWorkoutMetrics(state: context.state)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .accessibilityLabel("Workout")
            } compactTrailing: {
                if context.isStale {
                    Image(systemName: "wifi.slash")
                        .accessibilityLabel("Waiting for Watch")
                } else {
                    WorkoutElapsedTime(state: context.state)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: 60)
                }
            } minimal: {
                Image(systemName: "figure.run")
                    .accessibilityLabel("Workout")
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

private struct WatchWorkoutActivityContent: View {
    @Environment(\.activityFamily) private var activityFamily

    let state: WatchWorkoutSnapshot
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: activityFamily == .small ? 6 : 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(state.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if activityFamily != .small && !isStale {
                    WorkoutElapsedTime(state: state)
                        .font(.headline)
                }
            }

            WatchWorkoutStatus(state: state, isStale: isStale)

            if !isStale {
                if activityFamily == .small {
                    WorkoutElapsedTime(state: state)
                        .font(.title3)
                    WatchWorkoutMetrics(state: state, compact: true)
                } else {
                    WatchWorkoutMetrics(state: state)
                }
            }
        }
        .padding(activityFamily == .small ? 8 : 16)
    }
}

private struct WatchWorkoutStatus: View {
    let state: WatchWorkoutSnapshot
    let isStale: Bool

    var body: some View {
        Group {
            if isStale {
                Text("Waiting for Watch")
            } else {
                switch state.phase {
                case .running: Text("Workout")
                case .paused: Text("Paused")
                case .ended: Text("Workout Ended")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct WorkoutElapsedTime: View {
    let state: WatchWorkoutSnapshot

    var body: some View {
        Group {
            if state.phase == .running {
                Text(state.timerStartDate, style: .timer)
            } else {
                Text(Duration.seconds(state.elapsedSeconds).formatted(.time(pattern: .hourMinuteSecond)))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .accessibilityLabel("Elapsed Time")
        .accessibilityValue(accessibleValue)
    }

    private var accessibleValue: Text {
        if state.phase == .running {
            Text(state.timerStartDate, style: .timer)
        } else {
            Text(Duration.seconds(state.elapsedSeconds).formatted(.time(pattern: .hourMinuteSecond)))
        }
    }
}

private struct WatchWorkoutMetrics: View {
    let state: WatchWorkoutSnapshot
    var compact = false

    var body: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 2) {
                    metrics
                }
            } else {
                HStack(spacing: 12) {
                    metrics
                }
            }
        }
        .font(compact ? .caption2 : .caption)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var metrics: some View {
        if let heartRate = state.heartRate {
            Label {
                Text("\(Int(heartRate.rounded())) bpm")
            } icon: {
                Image(systemName: "heart.fill")
            }
            .accessibilityLabel("Heart Rate")
            .accessibilityValue(Text("\(Int(heartRate.rounded())) bpm"))
        }
        Label {
            Text("\(Int(state.activeCalories.rounded())) kcal")
        } icon: {
            Image(systemName: "flame.fill")
        }
        .accessibilityLabel("Active Calories")
        .accessibilityValue(Text("\(Int(state.activeCalories.rounded())) kcal"))

        if state.distanceMeters > 0 {
            Label {
                Text(Measurement(value: state.distanceMeters, unit: UnitLength.meters).formatted())
            } icon: {
                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
            }
            .accessibilityLabel("Distance")
            .accessibilityValue(Text(Measurement(value: state.distanceMeters, unit: UnitLength.meters).formatted()))
        }
    }
}
