import SwiftUI

@main
struct DailveWatchApp: App {
    @State private var connectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectivity)
                .onAppear {
                    connectivity.activate()
                }
        }
    }
}
