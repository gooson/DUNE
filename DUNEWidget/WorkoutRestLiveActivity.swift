import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutRestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutRestAttributes.self) { context in
            WorkoutRestActivityContent(context: context)
                .activityBackgroundTint(WidgetDS.isDesertWarm ? WidgetDS.Color.warmSurface : .black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest Timer", systemImage: "timer")
                        .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    restCountdown(context.state)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.exerciseName)
                        .lineLimit(1)
                        .privacySensitive()
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
            } compactTrailing: {
                CompactRestCountdown(state: context.state)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

private func restCountdown(_ state: WorkoutRestAttributes.ContentState) -> some View {
    Text(timerInterval: state.endDate.addingTimeInterval(-Double(state.totalDuration))...state.endDate,
         countsDown: true)
        .monospacedDigit()
}

private struct WorkoutRestActivityContent: View {
    @Environment(\.activityFamily) private var activityFamily

    let context: ActivityViewContext<WorkoutRestAttributes>

    var body: some View {
        Group {
            if activityFamily == .small {
                smallFamilyContent
            } else {
                lockScreenContent
            }
        }
        .padding(activityFamily == .small ? 8 : 16)
        .foregroundStyle(WidgetDS.isDesertWarm ? Color.primary : .white)
    }

    private var lockScreenContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rest Timer", systemImage: "timer")
                .font(.caption.weight(.bold))
                .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
            Text(context.attributes.exerciseName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .privacySensitive()
            HStack(alignment: .lastTextBaseline) {
                Text("Set \(context.attributes.setNumber)")
                    .font(.caption)
                Spacer()
                restCountdown(context.state)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
            }
        }
    }

    private var smallFamilyContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(context.attributes.exerciseName)
                .font(.headline)
                .lineLimit(1)
                .privacySensitive()
            Text("Set \(context.attributes.setNumber)")
                .font(.caption)
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .accessibilityLabel("Rest Timer")
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
                restCountdown(context.state)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CompactRestCountdown: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var isDynamicIslandLimitedInWidth

    let state: WorkoutRestAttributes.ContentState

    var body: some View {
        restCountdown(state)
            .font(isDynamicIslandLimitedInWidth ? .caption2 : .body)
            .lineLimit(1)
            .minimumScaleFactor(isDynamicIslandLimitedInWidth ? 0.75 : 1)
            .frame(maxWidth: isDynamicIslandLimitedInWidth ? 48 : 56)
            .foregroundStyle(WidgetDS.isDesertWarm ? WidgetDS.themeAccent : .white)
    }
}
