import SwiftUI

struct ContentView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    var body: some View {
        NavigationStack {
            if let activeWorkout = connectivity.activeWorkout {
                WorkoutActiveView(workout: activeWorkout)
            } else {
                WorkoutIdleView()
            }
        }
    }
}
