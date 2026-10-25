import ActivityKit
import SwiftUI
import WidgetKit

struct WatchWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WatchWorkoutAttributes.self) { context in
            WatchWorkoutActivityContent(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(WidgetDS.isDesertWarm ? WidgetDS.Color.warmSurface : .black.opacity(0.8))
                .activitySystemActionForegroundColor(WidgetDS.isDesertWarm ? WidgetDS.Color.warmInk : .white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WatchWorkoutHeader(state: context.state, isStale: context.isStale, isIsland: true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale {
                        WorkoutElapsedTime(state: context.state)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.isStale {
                        WatchWorkoutMetrics(state: context.state, isIsland: true)
                            .padding(.top, 8)
                    }
                }
            } compactLeading: {
                WatchWorkoutPhaseIcon(state: context.state, isStale: context.isStale)
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
            } compactTrailing: {
                if context.isStale {
                    Image(systemName: "wifi.slash")
                        .accessibilityLabel("Waiting for Watch")
                } else {
                    CompactWorkoutElapsedTime(state: context.state)
                }
            } minimal: {
                WatchWorkoutPhaseIcon(state: context.state, isStale: context.isStale)
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

private enum WorkoutPalette {
    static var primary: Color { WidgetDS.isDesertWarm ? WidgetDS.Color.warmInk : .white }
    static var secondary: Color { WidgetDS.isDesertWarm ? Color("DesertHorizonMuted") : .white.opacity(0.7) }
    static var accent: Color { WidgetDS.isDesertWarm ? WidgetDS.Color.warmAccent : .white }
    static let heart = Color("MetricHeartRate")
    static let calories = Color("MetricActivity")
    static let distance = Color("MetricSteps")
}

private struct WatchWorkoutActivityContent: View {
    @Environment(\.activityFamily) private var activityFamily

    let state: WatchWorkoutSnapshot
    let isStale: Bool
    var previewSmall = false

    private var isSmall: Bool { previewSmall || activityFamily == .small }

    var body: some View {
        Group {
            if isSmall {
                smallContent
            } else {
                fullContent
            }
        }
        .padding(isSmall ? 10 : 16)
        .foregroundStyle(WorkoutPalette.primary)
    }

    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            WatchWorkoutHeader(state: state, isStale: isStale)

            if !isStale {
                WorkoutElapsedTime(state: state)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(WorkoutPalette.accent)
                    .minimumScaleFactor(0.7)

                WatchWorkoutMetrics(state: state)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            WatchWorkoutHeader(state: state, isStale: isStale, compact: true)

            if !isStale {
                WorkoutElapsedTime(state: state)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WorkoutPalette.accent)
                    .minimumScaleFactor(0.7)

                WatchWorkoutMetrics(state: state, compact: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WatchWorkoutHeader: View {
    let state: WatchWorkoutSnapshot
    let isStale: Bool
    var compact = false
    var isIsland = false

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            WatchWorkoutPhaseIcon(state: state, isStale: isStale)
                .font(compact ? .subheadline : .body)
                .foregroundStyle(isIsland ? .white : WorkoutPalette.accent)
                .frame(width: compact ? 18 : 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(state.exerciseName)
                    .font(compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(isIsland ? .white : WorkoutPalette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
                    .accessibilityIdentifier("watch-workout-title")

                HStack(spacing: 6) {
                    Text(verbatim: "DUNE")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(isIsland ? WidgetDS.themeAccent : WorkoutPalette.accent)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityIdentifier("watch-workout-brand")

                    Text(verbatim: "·")
                        .font(.caption)
                        .foregroundStyle(isIsland ? Color.white.opacity(0.7) : WorkoutPalette.secondary)
                        .accessibilityHidden(true)

                    WatchWorkoutStatus(state: state, isStale: isStale, isIsland: isIsland)
                        .layoutPriority(-1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WatchWorkoutPhaseIcon: View {
    let state: WatchWorkoutSnapshot
    let isStale: Bool

    var body: some View {
        Image(systemName: symbol)
            .accessibilityLabel(accessibilityLabel)
    }

    private var symbol: String {
        if isStale { return "wifi.slash" }
        return switch state.phase {
        case .running: "figure"
        case .paused: "pause.fill"
        case .ended: "checkmark"
        }
    }

    private var accessibilityLabel: Text {
        if isStale { return Text("Waiting for Watch") }
        return switch state.phase {
        case .running: Text("Workout")
        case .paused: Text("Paused")
        case .ended: Text("Workout Ended")
        }
    }
}

private struct WatchWorkoutStatus: View {
    let state: WatchWorkoutSnapshot
    let isStale: Bool
    var isIsland = false

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
        .foregroundStyle(isIsland ? Color.white.opacity(0.7) : WorkoutPalette.secondary)
        .lineLimit(1)
        .accessibilityIdentifier("watch-workout-status")
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
        .accessibilityIdentifier("watch-workout-elapsed")
    }

    private var accessibleValue: Text {
        if state.phase == .running {
            Text(state.timerStartDate, style: .timer)
        } else {
            Text(Duration.seconds(state.elapsedSeconds).formatted(.time(pattern: .hourMinuteSecond)))
        }
    }
}

private struct CompactWorkoutElapsedTime: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var isLimitedInWidth

    let state: WatchWorkoutSnapshot

    var body: some View {
        if !isLimitedInWidth {
            WorkoutElapsedTime(state: state)
                .font(.caption2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: 60)
                .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
        }
    }
}

private struct WatchWorkoutMetrics: View {
    let state: WatchWorkoutSnapshot
    var compact = false
    var isIsland = false

    var body: some View {
        Group {
            if compact {
                basicMetricRows
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        basicMetrics
                        distanceMetric
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 6) {
                        basicMetricRows
                        distanceMetric
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .privacySensitive()
    }

    private var basicMetricRows: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: compact ? 10 : 16) {
                basicMetrics
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 4) {
                basicMetrics
            }
        }
    }

    @ViewBuilder
    private var basicMetrics: some View {
        if let heartRate = state.heartRate {
            metric(value: Text(Int(heartRate.rounded()).formatted()),
                   unit: Text("bpm"), symbol: "heart.fill", color: WorkoutPalette.heart,
                   label: Text("Heart Rate"), accessibleValue: Text("\(Int(heartRate.rounded())) bpm"))
        }

        metric(value: Text(Int(state.activeCalories.rounded()).formatted()),
               unit: Text("kcal"), symbol: "flame.fill", color: WorkoutPalette.calories,
               label: Text("Active Calories"), accessibleValue: Text("\(Int(state.activeCalories.rounded())) kcal"))
    }

    @ViewBuilder
    private var distanceMetric: some View {
        if state.distanceMeters > 0 {
            metric(value: Text(Measurement(value: state.distanceMeters, unit: UnitLength.meters).formatted()),
                   unit: nil, symbol: "location.fill", color: WorkoutPalette.distance,
                   label: Text("Distance"),
                   accessibleValue: Text(Measurement(value: state.distanceMeters, unit: UnitLength.meters).formatted()))
        }
    }

    private func metric(value: Text, unit: Text?, symbol: String, color: Color,
                        label: Text, accessibleValue: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 3 : 5) {
            Image(systemName: symbol)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            value
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(isIsland ? .white : WorkoutPalette.primary)

            if let unit {
                unit
                    .font(.caption2)
                    .foregroundStyle(isIsland ? Color.white.opacity(0.7) : WorkoutPalette.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibleValue)
        .accessibilityIdentifier(symbol == "heart.fill" ? "watch-workout-heart-rate" :
                                 (symbol == "flame.fill" ? "watch-workout-calories" : "watch-workout-distance"))
    }
}

#Preview("Watch workout · Running") {
    WatchWorkoutActivityContent(state: .previewRunning, isStale: false)
        .background(WidgetDS.Color.warmSurface)
}

#Preview("Watch workout · Paused") {
    WatchWorkoutActivityContent(state: .previewPaused, isStale: false)
        .background(WidgetDS.Color.warmSurface)
}

#Preview("Watch workout · Waiting") {
    WatchWorkoutActivityContent(state: .previewRunning, isStale: true)
        .background(WidgetDS.Color.warmSurface)
}

#Preview("Watch workout · Small") {
    WatchWorkoutActivityContent(state: .previewRunning, isStale: false, previewSmall: true)
        .background(WidgetDS.Color.warmSurface)
}

private extension WatchWorkoutSnapshot {
    static var previewRunning: Self {
        Self(startedAt: .now.addingTimeInterval(-1_373), updatedAt: .now,
             exerciseName: "Outdoor Run", elapsedSeconds: 1_373, phase: .running,
             heartRate: 142, activeCalories: 186, distanceMeters: 4_200)
    }

    static var previewPaused: Self {
        var snapshot = previewRunning
        snapshot.phase = .paused
        return snapshot
    }
}
