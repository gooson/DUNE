import SwiftUI
import WatchKit

/// Vertical TabView for active workout session.
/// Strength: Controls | MetricsView | NowPlaying (3 pages)
/// Cardio:   MainMetrics | HRZone | Secondary | Controls | NowPlaying (5 pages)
struct SessionPagingView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var selectedTab: SessionTab = .metrics

    var body: some View {
        TabView(selection: $selectedTab) {
            if workoutManager.isCardioMode {
                CardioMainMetricsPage()
                    .tag(SessionTab.cardioMain)

                CardioHRZonePage()
                    .tag(SessionTab.hrZone)

                CardioSecondaryPage()
                    .tag(SessionTab.cardioSecondary)
            } else {
                MetricsView()
                    .tag(SessionTab.metrics)
            }

            ControlsView()
                .tag(SessionTab.controls)

            NowPlayingView()
                .tag(SessionTab.nowPlaying)
        }
        .tabViewStyle(.verticalPage(transitionStyle: .blur))
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced {
                selectedTab = workoutManager.isCardioMode ? .cardioMain : .metrics
            }
        }
    }
}

enum SessionTab {
    case controls
    case metrics
    // Cardio-specific pages
    case cardioMain
    case hrZone
    case cardioSecondary
    case nowPlaying
}
