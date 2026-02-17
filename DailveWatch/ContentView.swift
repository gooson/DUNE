import SwiftUI

/// Root view: routes between RoutineList (idle), SessionPaging (active), and Summary (ended).
struct ContentView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity
    @State private var workoutManager = WorkoutManager.shared

    /// Captured once when session ends to avoid stale Date() on every body recompute.
    @State private var sessionEndDate: Date?

    var body: some View {
        NavigationStack {
            Group {
                if workoutManager.isSessionEnded, let endDate = sessionEndDate {
                    SessionSummaryView(
                        startDate: workoutManager.startDate ?? endDate,
                        endDate: endDate,
                        completedSetsData: workoutManager.completedSetsData,
                        averageHR: workoutManager.averageHeartRate,
                        maxHR: workoutManager.maxHeartRate,
                        activeCalories: workoutManager.activeCalories
                    )
                } else if workoutManager.isActive {
                    SessionPagingView()
                } else {
                    RoutineListView()
                }
            }
        }
        .environment(workoutManager)
        .onChange(of: workoutManager.isSessionEnded) { _, ended in
            if ended {
                sessionEndDate = Date()
            }
        }
        .task {
            await workoutManager.recoverSession()
        }
    }
}
