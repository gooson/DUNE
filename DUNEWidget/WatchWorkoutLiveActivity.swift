import ActivityKit
import SwiftUI
import WidgetKit

struct WatchWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WatchWorkoutAttributes.self) { context in
            WatchWorkoutActivityContent(state: context.state,
                                        isStale: context.isStale)
                .activityBackgroundTint(WidgetDS.isDesertWarm ? WidgetDS.Color.warmSurface : .black.opacity(0.8))
                .activitySystemActionForegroundColor(WidgetDS.isDesertWarm ? WidgetDS.Color.warmInk : .white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Workout", systemImage: "figure.run")
                        .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale {
                        WorkoutElapsedTime(state: context.state)
                            .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                            .privacySensitive()
                        WatchWorkoutStatus(state: context.state, isStale: context.isStale)
                        if !context.isStale {
                            WatchWorkoutMetrics(state: context.state)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase == .paused ? "pause.fill" : "figure.run")
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
                    .accessibilityLabel(context.state.phase == .paused ? Text("Paused") : Text("Workout"))
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
                        .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
                }
            } minimal: {
                Image(systemName: context.isStale ? "wifi.slash" : (context.state.phase == .paused ? "pause.fill" : "figure.run"))
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
                    .accessibilityLabel(context.isStale ? Text("Waiting for Watch")
                                        : (context.state.phase == .paused ? Text("Paused") : Text("Workout")))
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
                    .privacySensitive()
                Spacer(minLength: 0)
                if activityFamily != .small && !isStale {
                    WorkoutElapsedTime(state: state)
                        .font(.headline)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.Color.warmAccent : .white)
                }
            }

            WatchWorkoutStatus(state: state, isStale: isStale, usesWarmSurface: true)

            if !isStale {
                if activityFamily == .small {
                    WorkoutElapsedTime(state: state)
                        .font(.title3)
                        .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.Color.warmAccent : .white)
                    WatchWorkoutMetrics(state: state, compact: true)
                } else {
                    WatchWorkoutMetrics(state: state)
                }
            }
        }
        .padding(activityFamily == .small ? 8 : 16)
        .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.Color.warmInk : .white)
    }
}

private struct WatchWorkoutStatus: View {
    let state: WatchWorkoutSnapshot
    let isStale: Bool
    var usesWarmSurface = false

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
        .foregroundStyle(usesWarmSurface && WidgetDS.isDesertWarm ? WidgetDS.Color.warmInk.opacity(0.7) : .secondary)
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
        .privacySensitive()
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
