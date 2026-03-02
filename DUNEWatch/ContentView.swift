import SwiftUI

/// Type-safe navigation routes for Watch app (correction #61).
enum WatchRoute: Hashable {
    case quickStartAll
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

/// Root view: routes between CarouselHome (idle), SessionPaging (active), and Summary (ended).
struct ContentView: View {
    private struct NavigationObserverState: Equatable {
        let isActive: Bool
        let isSessionEnded: Bool
    }

    @Environment(WatchConnectivityManager.self) private var connectivity
    @State private var workoutManager = WorkoutManager.shared

    /// Captured once when session ends to avoid stale Date() on every body recompute.
    @State private var sessionEndDate: Date?

    /// Explicit path so we can pop pushed views when the root switches
    /// to SessionPagingView (correction #57).
    @State private var navigationPath = NavigationPath()

    private var navigationObserverState: NavigationObserverState {
        NavigationObserverState(
            isActive: workoutManager.isActive,
            isSessionEnded: workoutManager.isSessionEnded
        )
    }

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
                    CarouselHomeView()
                }
            }
            .navigationDestination(for: WatchRoute.self) { route in
                switch route {
                case .quickStartAll:
                    QuickStartAllExercisesView()
                case .workoutPreview(let snapshot):
                    WorkoutPreviewView(snapshot: snapshot)
                }
            }
        }
        .environment(workoutManager)
        .onChange(of: navigationObserverState) { old, new in
            let startedWorkout = !old.isActive && new.isActive
            let endedWorkout = !old.isSessionEnded && new.isSessionEnded

            if endedWorkout {
                sessionEndDate = Date()
            }

            // Avoid repeated NavigationStack updates in the same frame.
            guard startedWorkout || endedWorkout else { return }
            guard navigationPath.count > 0 else { return }
            navigationPath = NavigationPath()
        }
        .onChange(of: workoutManager.isSessionEnded) { _, ended in
            if !ended {
                sessionEndDate = nil
            }
        }
        .task {
            await workoutManager.recoverSession()
        }
    }
}
