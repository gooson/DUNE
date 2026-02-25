import SwiftUI

/// Type-safe navigation routes for Watch app (correction #61).
enum WatchRoute: Hashable {
    case quickStart
    case workoutPreview(WorkoutSessionTemplate)
}

// WorkoutSessionTemplate needs Hashable for navigation value
extension WorkoutSessionTemplate: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name && lhs.entries.count == rhs.entries.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(entries.count)
    }
}

/// Root view: routes between RoutineList (idle), SessionPaging (active), and Summary (ended).
struct ContentView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity
    @State private var workoutManager = WorkoutManager.shared

    /// Captured once when session ends to avoid stale Date() on every body recompute.
    @State private var sessionEndDate: Date?

    /// Explicit path so we can pop pushed views (e.g. QuickStartPickerView)
    /// when the root switches to SessionPagingView (correction #57).
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
            .navigationDestination(for: WatchRoute.self) { route in
                switch route {
                case .quickStart:
                    QuickStartPickerView()
                case .workoutPreview(let snapshot):
                    WorkoutPreviewView(snapshot: snapshot)
                }
            }
        }
        .environment(workoutManager)
        .onChange(of: workoutManager.isActive) { old, new in
            // Pop all pushed views when workout starts (correction #57, #60)
            if !old, new {
                navigationPath = NavigationPath()
            }
        }
        .onChange(of: workoutManager.isSessionEnded) { _, ended in
            if ended {
                sessionEndDate = Date()
                navigationPath = NavigationPath()
            }
        }
        .task {
            await workoutManager.recoverSession()
        }
    }
}
