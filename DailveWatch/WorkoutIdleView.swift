import SwiftUI

/// Shown when no workout is active. Displays waiting state or quick-start options.
struct WorkoutIdleView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Dailve")
                .font(.headline)

            if connectivity.isReachable {
                Text("Start a workout\non your iPhone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Label("iPhone not connected", systemImage: "iphone.slash")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if !connectivity.exerciseLibrary.isEmpty {
                NavigationLink {
                    QuickStartView()
                } label: {
                    Label("Quick Start", systemImage: "bolt.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
    }
}
