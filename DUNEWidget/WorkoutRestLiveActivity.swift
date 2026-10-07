import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutRestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutRestAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text("Rest Timer").font(.headline)
                Text(context.attributes.exerciseName).font(.subheadline)
                HStack {
                    Text("Set \(context.attributes.setNumber)")
                    Spacer()
                    countdown(context.state)
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest Timer", systemImage: "timer")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.exerciseName)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                countdown(context.state).frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func countdown(_ state: WorkoutRestAttributes.ContentState) -> some View {
        Text(timerInterval: state.endDate.addingTimeInterval(-Double(state.totalDuration))...state.endDate,
             countsDown: true)
            .monospacedDigit()
    }
}
