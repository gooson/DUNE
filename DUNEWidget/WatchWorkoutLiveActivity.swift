import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct WatchWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        return ActivityConfiguration(for: WatchWorkoutAttributes.self) { context in
            let state = context.state.snapshot
            let preferences = context.state.preferences
            let palette = WorkoutPalette(style: preferences.style)
            WatchWorkoutActivityContent(state: state, isStale: context.isStale, preferences: preferences)
                .environment(\.workoutLiveActivityStyle, preferences.style)
                .activityBackgroundTint(palette.usesWarmSurface ? WidgetDS.Color.warmSurface : .black.opacity(0.8))
                .activitySystemActionForegroundColor(palette.usesWarmSurface ? WidgetDS.Color.warmInk : .white)
        } dynamicIsland: { context in
            let state = context.state.snapshot
            let preferences = context.state.preferences
            let palette = WorkoutPalette(style: preferences.style)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WatchWorkoutHeader(state: state, isStale: context.isStale, isIsland: true)
                        .environment(\.workoutLiveActivityStyle, preferences.style)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale && preferences.style == .standard {
                        WorkoutPrimaryMetric(state: state, preferences: preferences)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.isStale {
                        VStack(alignment: .leading, spacing: 10) {
                            if preferences.style == .goldImpact {
                                WorkoutMetricHero(state: state, preferences: preferences, isIsland: true)
                            } else if preferences.resolvedMetric(for: state) != .elapsedTime {
                                WorkoutElapsedTime(state: state)
                                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                            }
                            WatchWorkoutMetrics(state: state, isIsland: true,
                                                primaryMetric: preferences.resolvedMetric(for: state))
                        }
                        .padding(.top, 8)
                        .environment(\.workoutLiveActivityStyle, preferences.style)
                    }
                }
            } compactLeading: {
                if !context.isStale, state.phase == .running,
                   preferences.resolvedMetric(for: state) == .heartRate {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(WorkoutPalette.heart)
                        .accessibilityLabel("Heart Rate")
                } else {
                    WatchWorkoutPhaseIcon(state: state, isStale: context.isStale)
                        .foregroundStyle(palette.usesWarmSurface ? palette.islandAccent : .white)
                }
            } compactTrailing: {
                if context.isStale {
                    Image(systemName: "wifi.slash")
                        .accessibilityLabel("Waiting for Watch")
                } else {
                    WorkoutIslandMetric(state: state, preferences: preferences)
                }
            } minimal: {
                if context.isStale || state.phase != .running {
                    WatchWorkoutPhaseIcon(state: state, isStale: context.isStale)
                        .foregroundStyle(palette.islandAccent)
                } else {
                    WorkoutIslandMetric(state: state, preferences: preferences, minimal: true)
                }
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

private struct WorkoutLiveActivityStyleKey: EnvironmentKey {
    static let defaultValue = WorkoutLiveActivityStyle.goldImpact
}

private extension EnvironmentValues {
    var workoutLiveActivityStyle: WorkoutLiveActivityStyle {
        get { self[WorkoutLiveActivityStyleKey.self] }
        set { self[WorkoutLiveActivityStyleKey.self] = newValue }
    }
}

private struct WorkoutPalette {
    let style: WorkoutLiveActivityStyle
    var isGold: Bool { style == .goldImpact }
    var usesWarmSurface: Bool { WidgetDS.isDesertWarm || isGold }
    var primary: Color { usesWarmSurface ? WidgetDS.Color.warmInk : .white }
    var secondary: Color { usesWarmSurface ? Color("DesertHorizonMuted") : .white.opacity(0.7) }
    var accent: Color { usesWarmSurface ? WidgetDS.Color.warmAccent : .white }
    var islandAccent: Color { isGold ? Color("WorkoutMedalGold") : WidgetDS.themeAccent }
    static let heart = Color("MetricHeartRate")
    static let calories = Color("MetricActivity")
    static let distance = Color("MetricSteps")
}

private struct WatchWorkoutActivityContent: View {
    private var palette: WorkoutPalette { WorkoutPalette(style: preferences.style) }
    @Environment(\.activityFamily) private var activityFamily
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground

    let state: WatchWorkoutSnapshot
    let isStale: Bool
    var previewSmall = false
    var preferences = WorkoutLiveActivityPreferences()

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
        .foregroundStyle(palette.primary)
        .background {
            if preferences.style == .goldImpact && showsContainerBackground {
                WorkoutGoldSurface()
            }
        }
    }

    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            WatchWorkoutHeader(state: state, isStale: isStale)

            if !isStale {
                WorkoutMetricHero(state: state, preferences: preferences)

                WatchWorkoutMetrics(state: state, primaryMetric: preferences.resolvedMetric(for: state))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            WatchWorkoutHeader(state: state, isStale: isStale, compact: true)

            if !isStale {
                WorkoutPrimaryMetric(state: state, preferences: preferences)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(palette.accent)
                    .minimumScaleFactor(0.7)

                if preferences.resolvedMetric(for: state) != .elapsedTime {
                    WorkoutElapsedTime(state: state).font(.caption2)
                }
                WatchWorkoutMetrics(state: state, compact: true,
                                    primaryMetric: preferences.resolvedMetric(for: state))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WatchWorkoutHeader: View {
    @Environment(\.workoutLiveActivityStyle) private var activityStyle
    private var palette: WorkoutPalette { WorkoutPalette(style: activityStyle) }
    let state: WatchWorkoutSnapshot
    let isStale: Bool
    var compact = false
    var isIsland = false

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            WatchWorkoutPhaseIcon(state: state, isStale: isStale)
                .font(compact ? .subheadline : .body)
                .foregroundStyle(isIsland ? .white : palette.accent)
                .frame(width: compact ? 18 : 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(state.exerciseName)
                    .font(compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(isIsland ? .white : palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
                    .accessibilityIdentifier("watch-workout-title")

                HStack(spacing: 6) {
                    Text(verbatim: "DUNE")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(isIsland ? palette.islandAccent : palette.accent)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityIdentifier("watch-workout-brand")

                    Text(verbatim: "·")
                        .font(.caption)
                        .foregroundStyle(isIsland ? Color.white.opacity(0.7) : palette.secondary)
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
    private let symbol: String

    init(state: WatchWorkoutSnapshot, isStale: Bool) {
        self.state = state
        self.isStale = isStale
        let proposed = state.phaseIconName(isStale: isStale)
        symbol = UIImage(systemName: proposed) == nil ? "figure" : proposed
    }

    var body: some View {
        Image(systemName: symbol)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier("watch-workout-icon-\(symbol)")
            .privacySensitive()
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
    @Environment(\.workoutLiveActivityStyle) private var activityStyle
    private var palette: WorkoutPalette { WorkoutPalette(style: activityStyle) }
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
        .foregroundStyle(isIsland ? Color.white.opacity(0.7) : palette.secondary)
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

private struct WorkoutIslandMetric: View {
    private var palette: WorkoutPalette { WorkoutPalette(style: preferences.style) }
    @Environment(\.isDynamicIslandLimitedInWidth) private var isLimitedInWidth

    let state: WatchWorkoutSnapshot
    let preferences: WorkoutLiveActivityPreferences
    var minimal = false

    var body: some View {
        let constrained = isLimitedInWidth || minimal
        ViewThatFits(in: .horizontal) {
            WorkoutPrimaryMetric(state: state, preferences: preferences, abbreviated: constrained)
                .font(.caption2.weight(.semibold))
                .fixedSize(horizontal: constrained, vertical: false)
            if preferences.resolvedMetric(for: state) == .elapsedTime {
                Image(systemName: "timer")
                    .accessibilityLabel("Elapsed Time")
                    .accessibilityValue(state.phase == .running ? Text(state.timerStartDate, style: .timer) :
                                          Text(Duration.seconds(state.elapsedSeconds).formatted(.time(pattern: .hourMinuteSecond))))
            } else {
                Image(systemName: preferences.resolvedMetric(for: state) == .heartRate ? "heart.fill" :
                        (preferences.resolvedMetric(for: state) == .weight ? "dumbbell.fill" : "location.fill"))
                    .accessibilityLabel(Text(preferences.resolvedMetric(for: state).displayName))
                    .accessibilityValue(Text(verbatim: preferences.resolvedMetric(for: state) == .weight ?
                                             "\((state.currentSetWeightKg ?? 0).formatted()) kg" :
                                             (preferences.resolvedMetric(for: state) == .distance ?
                                              "\((state.distanceMeters / 1_000).formatted()) km" :
                                              "\(Int((state.heartRate ?? 0).rounded()).formatted()) bpm")))
            }
        }
        .frame(width: isLimitedInWidth ? 28 : (minimal ? 45 : 60), height: isLimitedInWidth ? 28 : nil)
        .foregroundStyle(palette.usesWarmSurface ? palette.islandAccent : .white)
        .privacySensitive()
    }
}

private struct WorkoutPrimaryMetric: View {
    let state: WatchWorkoutSnapshot
    let preferences: WorkoutLiveActivityPreferences
    var abbreviated = false

    private var metric: WorkoutLiveActivityMetric { preferences.resolvedMetric(for: state) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
          Group {
            if metric == .elapsedTime {
                WorkoutElapsedTime(state: state)
            } else {
                metricValue
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(metric.displayName))
                    .accessibilityValue(Text(verbatim: "\(fullValue) \(unit)"))
                    .accessibilityIdentifier(metric == .distance ? "watch-workout-distance" :
                                               (metric == .weight ? "watch-workout-weight" : "watch-workout-heart-rate"))
            }
          }
        }
        .monospacedDigit()
        .lineLimit(1)
        .privacySensitive()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch-workout-primary-metric")
    }

    private var metricValue: some View {
        Group {
            if abbreviated {
                VStack(spacing: 0) {
                    if metric == .heartRate {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8)).foregroundStyle(WorkoutPalette.heart)
                    }
                    Text(verbatim: value)
                    if metric != .heartRate {
                        Text(verbatim: unit).font(.system(size: 8))
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: value)
                    Text(verbatim: unit).font(.caption)
                }
            }
        }
    }

    private var value: String {
        switch metric {
        case .distance: (state.distanceMeters / 1_000).formatted(.number.precision(.fractionLength(abbreviated ? 1 : 2)))
        case .weight: (state.currentSetWeightKg ?? 0).formatted(.number.precision(.fractionLength(0...2)))
        case .heartRate: Int((state.heartRate ?? 0).rounded()).formatted()
        case .elapsedTime: ""
        }
    }

    private var fullValue: String {
        if metric == .distance {
            return (state.distanceMeters / 1_000).formatted(.number.precision(.fractionLength(0...3)))
        }
        return value
    }

    private var unit: String {
        switch metric {
        case .distance: "km"
        case .weight: "kg"
        case .heartRate: "bpm"
        case .elapsedTime: ""
        }
    }
}

private struct WorkoutMetricHero: View {
    private var palette: WorkoutPalette { WorkoutPalette(style: preferences.style) }
    let state: WatchWorkoutSnapshot
    let preferences: WorkoutLiveActivityPreferences
    var isIsland = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    WorkoutPrimaryMetric(state: state, preferences: preferences)
                        .fixedSize(horizontal: true, vertical: false)
                    if preferences.style == .goldImpact {
                        WorkoutGoldEmblem(state: state)
                    }
                }
                WorkoutPrimaryMetric(state: state, preferences: preferences)
                    .minimumScaleFactor(0.75)
            }
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundStyle(isIsland ? palette.islandAccent : palette.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            if preferences.resolvedMetric(for: state) != .elapsedTime {
                WorkoutElapsedTime(state: state)
                    .font(.caption)
                    .foregroundStyle(isIsland ? .white.opacity(0.7) : palette.secondary)
            }
        }
    }
}

private struct WorkoutGoldEmblem: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let state: WatchWorkoutSnapshot

    var body: some View {
        if !dynamicTypeSize.isAccessibilitySize {
            WatchWorkoutPhaseIcon(state: state, isStale: false)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color("WorkoutMedalEngraving"))
                .frame(width: 56, height: 62)
                .background {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(LinearGradient(colors: [Color("WorkoutMedalGold"), WidgetDS.Color.warmAccent],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1).padding(4)
                        }
                }
                .rotationEffect(.degrees(7))
                .opacity(state.phase == .paused ? 0.55 : 1)
                .accessibilityHidden(true)
        }
    }
}

private struct WorkoutGoldSurface: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [WidgetDS.Color.warmSurface, WidgetDS.Color.warmTile],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse()
                    .fill(WidgetDS.Color.warmAccent.opacity(0.12))
                    .frame(width: geometry.size.width * 1.7, height: 90)
                    .rotationEffect(.degrees(-12)).offset(y: 65)
                Ellipse()
                    .fill(WidgetDS.Color.warmAccent.opacity(0.08))
                    .frame(width: geometry.size.width * 1.5, height: 80)
                    .rotationEffect(.degrees(10)).offset(x: 65, y: 57)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WatchWorkoutMetrics: View {
    @Environment(\.workoutLiveActivityStyle) private var activityStyle
    private var palette: WorkoutPalette { WorkoutPalette(style: activityStyle) }
    let state: WatchWorkoutSnapshot
    var compact = false
    var isIsland = false
    var primaryMetric: WorkoutLiveActivityMetric = .elapsedTime

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
        if primaryMetric != .heartRate, let heartRate = state.heartRate {
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
        if primaryMetric != .distance, state.supportsDistance == true {
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
                .foregroundStyle(isIsland ? .white : palette.primary)

            if let unit {
                unit
                    .font(.caption2)
                    .foregroundStyle(isIsland ? Color.white.opacity(0.7) : palette.secondary)
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
             heartRate: 142, activeCalories: 186, distanceMeters: 4_200,
             exerciseIconName: "figure.run")
    }

    static var previewPaused: Self {
        var snapshot = previewRunning
        snapshot.phase = .paused
        return snapshot
    }
}
