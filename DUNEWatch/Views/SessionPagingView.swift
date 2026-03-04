import SwiftUI
import WatchKit

/// Active workout session paging.
/// Strength: Vertical pages — Controls | MetricsView | NowPlaying (3 pages, Digital Crown)
/// Cardio:   Horizontal pages — Controls | MainMetrics | HRZone | Secondary | NowPlaying (5 pages, swipe)
///           Controls accessible via single right swipe from default MainMetrics page.
struct SessionPagingView: View {
    let isCardioMode: Bool

    var body: some View {
        if isCardioMode {
            CardioSessionPagingView()
        } else {
            StrengthSessionPagingView()
        }
    }
}

// MARK: - Cardio: Flat horizontal paging (Apple Fitness pattern)

private struct CardioSessionPagingView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var selectedTab: CardioTab = .mainMetrics

    var body: some View {
        TabView(selection: $selectedTab) {
            ControlsView(showSkip: false)
                .tag(CardioTab.controls)

            CardioMainMetricsPage()
                .tag(CardioTab.mainMetrics)

            CardioHRZonePage()
                .tag(CardioTab.hrZone)

            CardioSecondaryPage()
                .tag(CardioTab.secondary)

            NowPlayingView()
                .tag(CardioTab.nowPlaying)
        }
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced {
                selectedTab = .mainMetrics
            }
        }
    }

    private enum CardioTab {
        case controls
        case mainMetrics
        case hrZone
        case secondary
        case nowPlaying
    }
}

// MARK: - Strength: Vertical paging (unchanged)

private struct StrengthSessionPagingView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var selectedTab: StrengthTab = .metrics

    var body: some View {
        TabView(selection: $selectedTab) {
            ControlsView()
                .tag(StrengthTab.controls)

            MetricsView()
                .tag(StrengthTab.metrics)

            NowPlayingView()
                .tag(StrengthTab.nowPlaying)
        }
        .tabViewStyle(.verticalPage(transitionStyle: .blur))
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced {
                selectedTab = .metrics
            }
        }
    }

    private enum StrengthTab {
        case controls
        case metrics
        case nowPlaying
    }
}
