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
    @Environment(WorkoutManager.self) private var workoutManager
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
        .onChange(of: workoutManager.cardioInactivityPrompt) { oldValue, newValue in
            guard oldValue != newValue else { return }
            switch newValue {
            case .softNudge:
                WKInterfaceDevice.current().play(.start)
            case .confirmation:
                WKInterfaceDevice.current().play(.notification)
            case nil:
                break
            }
        }
        .alert(
            cardioAlertTitle,
            isPresented: cardioInactivityAlertBinding,
            actions: {
                switch workoutManager.cardioInactivityPrompt {
                case .softNudge:
                    Button("Keep Running") {
                        workoutManager.keepCardioWorkoutRunning()
                    }
                    Button("Pause") {
                        workoutManager.pauseFromCardioInactivityPrompt()
                    }
                    Button("End Workout", role: .destructive) {
                        workoutManager.end()
                    }
                case .confirmation:
                    Button("Keep Running") {
                        workoutManager.keepCardioWorkoutRunning()
                    }
                    Button("End Now", role: .destructive) {
                        workoutManager.end()
                    }
                case nil:
                    Button("OK", role: .cancel) {
                        workoutManager.keepCardioWorkoutRunning()
                    }
                }
            },
            message: {
                Text(cardioAlertMessage)
            }
        )
    }

    private var cardioInactivityAlertBinding: Binding<Bool> {
        Binding(
            get: { workoutManager.cardioInactivityPrompt != nil },
            set: { newValue in
                if !newValue {
                    workoutManager.keepCardioWorkoutRunning()
                }
            }
        )
    }

    private var cardioAlertTitle: String {
        switch workoutManager.cardioInactivityPrompt {
        case .softNudge:
            return String(localized: "No movement detected")
        case .confirmation:
            return String(localized: "End workout soon?")
        case nil:
            return ""
        }
    }

    private var cardioAlertMessage: String {
        switch workoutManager.cardioInactivityPrompt {
        case .softNudge:
            return String(localized: "We haven't detected movement for a while. Are you still working out?")
        case .confirmation:
            let countdown = workoutManager.cardioAutoEndCountdown ?? 0
            return String(localized: "Ending in \(countdown)s unless you continue.")
        case nil:
            return ""
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
