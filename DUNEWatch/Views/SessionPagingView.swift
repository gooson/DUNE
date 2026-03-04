import SwiftUI
import WatchKit

/// Active workout session paging.
/// Strength: Vertical pages — Controls | MetricsView | NowPlaying (3 pages)
/// Cardio:   Horizontal pages — CardioControls (left) ←→ Vertical metrics (right, default)
///           Vertical metrics: MainMetrics | HRZone | Secondary | NowPlaying (4 pages)
struct SessionPagingView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        if workoutManager.isCardioMode {
            CardioSessionPagingView()
        } else {
            StrengthSessionPagingView()
        }
    }
}

// MARK: - Cardio: Horizontal swipe for controls + vertical metric pages

private struct CardioSessionPagingView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var horizontalPage: CardioHorizontalPage = .metrics
    @State private var selectedTab: SessionTab = .cardioMain

    var body: some View {
        TabView(selection: $horizontalPage) {
            CardioControlsView()
                .tag(CardioHorizontalPage.controls)

            TabView(selection: $selectedTab) {
                CardioMainMetricsPage()
                    .tag(SessionTab.cardioMain)

                CardioHRZonePage()
                    .tag(SessionTab.hrZone)

                CardioSecondaryPage()
                    .tag(SessionTab.cardioSecondary)

                NowPlayingView()
                    .tag(SessionTab.nowPlaying)
            }
            .tabViewStyle(.verticalPage(transitionStyle: .blur))
            .tag(CardioHorizontalPage.metrics)
        }
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced {
                horizontalPage = .metrics
                selectedTab = .cardioMain
            }
        }
    }
}

// MARK: - Strength: Original vertical paging (unchanged)

private struct StrengthSessionPagingView: View {
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

// MARK: - Tab Enums

private enum CardioHorizontalPage {
    case controls
    case metrics
}

enum SessionTab {
    case controls
    case metrics
    case cardioMain
    case hrZone
    case cardioSecondary
    case nowPlaying
}
