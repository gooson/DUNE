import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutRestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutRestAttributes.self) { context in
            WorkoutRestActivityContent(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest Timer", systemImage: "timer")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    restCountdown(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.exerciseName)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                CompactRestCountdown(state: context.state)
            } minimal: {
                Image(systemName: "timer")
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
    }

    private var lockScreenContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rest Timer").font(.headline)
            Text(context.attributes.exerciseName).font(.subheadline)
            HStack {
                Text("Set \(context.attributes.setNumber)")
                Spacer()
                restCountdown(context.state)
            }
        }
    }

    private var smallFamilyContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(context.attributes.exerciseName)
                .font(.headline)
                .lineLimit(1)
            Text("Set \(context.attributes.setNumber)")
                .font(.caption)
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .accessibilityLabel("Rest Timer")
                restCountdown(context.state)
                    .font(.title3)
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
    }
}
