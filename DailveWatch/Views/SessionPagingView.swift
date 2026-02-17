import SwiftUI
import WatchKit

/// 3-Page vertical TabView for active workout session.
/// Layout: Controls (top) | Metrics (center) | Now Playing (bottom)
struct SessionPagingView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var selectedTab: SessionTab = .metrics

    var body: some View {
        TabView(selection: $selectedTab) {
            ControlsView()
                .tag(SessionTab.controls)

            MetricsView()
                .tag(SessionTab.metrics)

            NowPlayingView()
                .tag(SessionTab.nowPlaying)
        }
        .tabViewStyle(.verticalPage(transitionStyle: .blur))
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced {
                selectedTab = .metrics
            }
        }
    }
}

enum SessionTab {
    case controls
    case metrics
    case nowPlaying
}
