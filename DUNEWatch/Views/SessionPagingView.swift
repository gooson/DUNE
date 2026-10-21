import SwiftUI
import WatchKit

/// Active workout session paging.
/// Strength: Vertical pages — Controls | MetricsView | NowPlaying (3 pages, Digital Crown)
/// Cardio:   Horizontal pages — Controls | MainMetrics | HRZone | Secondary | NowPlaying (5 pages, swipe)
///           Controls accessible via single right swipe from default MainMetrics page.
struct SessionPagingView: View {
    let isCardioMode: Bool

    var body: some View {
        Group {
            if isCardioMode {
                CardioSessionPagingView()
            } else {
                StrengthSessionPagingView()
            }
        }
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionPagingRoot)
    }
}

// MARK: - Cardio: Flat horizontal paging (Apple Fitness pattern)

private struct CardioSessionPagingView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    @State private var selectedTab: CardioTab = .mainMetrics
    @State private var announcedKilometer: Int?
    @State private var milestoneDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ControlsView(showSkip: false)
                    .tag(CardioTab.controls)

                CardioMainMetricsPage()
                    .tag(CardioTab.mainMetrics)

                CardioHRZonePage(milestoneKilometer: announcedKilometer)
                    .tag(CardioTab.hrZone)

                CardioSecondaryPage()
                    .tag(CardioTab.secondary)

                NowPlayingView()
                    .tag(CardioTab.nowPlaying)
            }
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionPagingCardio)

            if selectedTab != .hrZone, let announcedKilometer {
                CardioDistanceMilestoneBanner(kilometer: announcedKilometer)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
        .onChange(of: selectedTab) { _, tab in
#if DEBUG && targetEnvironment(simulator)
            if tab == .hrZone {
                workoutManager.simulateKilometerMilestoneIfRequested()
            }
#endif
        }
        .onChange(of: workoutManager.latestDistanceMilestone) { _, kilometer in
            milestoneDismissTask?.cancel()
            announcedKilometer = kilometer
            guard kilometer != nil else { return }
            milestoneDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                announcedKilometer = nil
            }
        }
        .onDisappear {
            milestoneDismissTask?.cancel()
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

struct CardioDistanceMilestoneBanner: View {
    let kilometer: Int

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "figure.run")
            Text(kilometer, format: .number)
                .fontWeight(.bold)
            Text("km")
            Text("reached")
                .accessibilityIdentifier("watch-cardio-distance-milestone")
        }
        .font(DS.Typography.metricLabel)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(.regularMaterial, in: Capsule())
        .allowsHitTesting(false)
    }
}

// MARK: - Strength: Vertical paging (unchanged)

private struct StrengthSessionPagingView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var selectedTab: StrengthTab = Self.initialTab

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
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionPagingStrength)
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

    private static var initialTab: StrengthTab {
        ProcessInfo.processInfo.arguments.contains("--ui-watch-strength-start-controls") ? .controls : .metrics
    }
}
