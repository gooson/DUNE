import SwiftUI
import WatchKit

/// 3-Page vertical TabView for active workout session.
/// Strength: Controls | MetricsView | NowPlaying
/// Cardio:   Controls | CardioMetricsView | NowPlaying
struct SessionPagingView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var selectedTab: SessionTab = .metrics

    var body: some View {
        TabView(selection: $selectedTab) {
            ControlsView()
                .tag(SessionTab.controls)

            if workoutManager.isCardioMode {
                CardioMetricsView()
                    .tag(SessionTab.metrics)
            } else {
                MetricsView()
                    .tag(SessionTab.metrics)
            }

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
