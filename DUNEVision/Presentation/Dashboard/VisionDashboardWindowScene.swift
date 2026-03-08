import SwiftUI

struct VisionDashboardWindowScene: View {
    let kind: VisionDashboardWindowKind
    @State private var viewModel: VisionDashboardWorkspaceViewModel

    init(
        kind: VisionDashboardWindowKind,
        sharedHealthDataService: SharedHealthDataService? = nil,
        workoutService: WorkoutQuerying? = nil
    ) {
        self.kind = kind
        _viewModel = State(
            initialValue: VisionDashboardWorkspaceViewModel(
                sharedHealthDataService: sharedHealthDataService,
                workoutService: workoutService
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    loadingState
                case .unavailable(let message), .failed(let message):
                    unavailableState(message)
                case .ready:
                    readyContent
                }
            }
            .navigationTitle(kind.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.reload()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowRefreshButtonID(for: kind))
                }
            }
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowRootID(for: kind))
        .task {
            await viewModel.loadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .simulatorAdvancedMockDataDidChange)) { _ in
            Task {
                await viewModel.reload()
            }
        }
    }

    private var readyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                detailCards
                if kind == .activity {
                    recentSessionsSection
                }
                if let message = viewModel.message {
                    messageCard(message)
                }
            }
            .padding(24)
        }
        .background(windowBackground)
    }

    private var heroCard: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(kind.title)
                    .font(.title2.weight(.semibold))

                switch kind {
                case .condition:
                    conditionHeroContent
                case .activity:
                    activityHeroContent
                case .sleep:
                    sleepHeroContent
                case .body:
                    bodyHeroContent
                }
            }

            Spacer()
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowHeroCardID(for: kind))
    }

    @ViewBuilder
    private var conditionHeroContent: some View {
        if let condition = viewModel.summary?.condition {
            HStack(alignment: .bottom, spacing: 14) {
                Text(condition.score.map { $0.formatted() } ?? "--")
                    .font(.system(size: 68, weight: .bold, design: .rounded))

                if let status = condition.status {
                    Text(status.label)
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                }
            }

            if let narrative = condition.narrative {
                Text(narrative)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var activityHeroContent: some View {
        if let activity = viewModel.summary?.activity {
            Text(durationString(minutes: activity.totalMinutes))
                .font(.system(size: 52, weight: .bold, design: .rounded))

            Text(activityDateRangeLabel)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var sleepHeroContent: some View {
        if let sleep = viewModel.summary?.sleep {
            Text(hoursString(minutes: sleep.totalMinutes))
                .font(.system(size: 52, weight: .bold, design: .rounded))

            if let sampleDate = sleep.sampleDate {
                Text(sampleDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var bodyHeroContent: some View {
        if let body = viewModel.summary?.body {
            Text(body.weightKg.map { numberString($0, digits: 1) } ?? "--")
                .font(.system(size: 52, weight: .bold, design: .rounded))

            if let sampleDate = body.sampleDate {
                Text(sampleDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailCards: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]

        return LazyVGrid(columns: columns, spacing: 14) {
            switch kind {
            case .condition:
                conditionCards
            case .activity:
                activityCards
            case .sleep:
                sleepCards
            case .body:
                bodyCards
            }
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowDetailSectionID(for: kind))
    }

    @ViewBuilder
    private var conditionCards: some View {
        if let condition = viewModel.summary?.condition {
            statCard(
                title: String(localized: "HRV"),
                value: condition.latestHRV.map { numberString($0, digits: 0) } ?? "--"
            )
            statCard(
                title: String(localized: "Resting HR"),
                value: condition.restingHeartRate.map { numberString($0, digits: 0) } ?? "--"
            )
            statCard(
                title: String(localized: "Recovery"),
                value: baselineProgressValue(condition)
            )
        }
    }

    @ViewBuilder
    private var activityCards: some View {
        if let activity = viewModel.summary?.activity {
            statCard(
                title: String(localized: "Training Load"),
                value: durationString(minutes: activity.totalMinutes)
            )
            statCard(
                title: String(localized: "Active Days"),
                value: activity.activeDays.formatted()
            )
            statCard(
                title: activity.topWorkoutTitle ?? String(localized: "Workout"),
                value: activity.topWorkoutMinutes.map { durationString(minutes: $0) } ?? "--",
                detail: activity.featuredMuscle.map { $0.displayName }
            )

            if let featuredMuscle = activity.featuredMuscle,
               let loadUnits = activity.featuredMuscleLoadUnits {
                statCard(
                    title: featuredMuscle.displayName,
                    value: loadUnits.formatted(),
                    detail: activity.featuredMuscleRecoveryPercent.map {
                        $0.formatted(.percent.precision(.fractionLength(0)))
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var sleepCards: some View {
        if let sleep = viewModel.summary?.sleep {
            statCard(
                title: String(localized: "Recovery"),
                value: sleep.score.map { $0.formatted() } ?? "--"
            )
            statCard(
                title: String(localized: "Deep"),
                value: sleep.deepSleepRatio?.formatted(.percent.precision(.fractionLength(0))) ?? "--"
            )
            statCard(
                title: String(localized: "REM"),
                value: sleep.remSleepRatio?.formatted(.percent.precision(.fractionLength(0))) ?? "--"
            )
        }
    }

    @ViewBuilder
    private var bodyCards: some View {
        if let body = viewModel.summary?.body {
            statCard(
                title: String(localized: "Weight"),
                value: body.weightKg.map { numberString($0, digits: 1) } ?? "--"
            )
            statCard(
                title: String(localized: "Body Fat"),
                value: body.bodyFatPercentage.map { numberString($0, digits: 1) } ?? "--"
            )
            statCard(
                title: String(localized: "Lean Body Mass"),
                value: body.leanBodyMassKg.map { numberString($0, digits: 1) } ?? "--"
            )
        }
    }

    @ViewBuilder
    private var recentSessionsSection: some View {
        if let activity = viewModel.summary?.activity {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Sessions")
                    .font(.headline)

                if activity.recentWorkouts.isEmpty {
                    VStack(spacing: 8) {
                        Text("No data available")
                            .font(.callout)
                        Text("Start tracking on iPhone or Apple Watch.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    ForEach(activity.recentWorkouts) { workout in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: workout.title)
                                    .font(.headline)
                                Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(durationString(seconds: workout.duration))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
            }
            .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowActivityRecentSessions)
        }
    }

    private func statCard(
        title: String,
        value: String,
        detail: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(verbatim: value)
                .font(.title3.weight(.semibold))

            if let detail {
                Text(verbatim: detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func messageCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.badge.exclamationmark")
                .foregroundStyle(.tint)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowMessageCardID(for: kind))
    }

    private func unavailableState(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.tint)
            Text(kind.title)
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(windowBackground)
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowUnavailableStateID(for: kind))
    }

    private var loadingState: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Image(systemName: kind.systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.tint)
            Text(kind.title)
                .font(.title2.weight(.semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(windowBackground)
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowLoadingStateID(for: kind))
    }

    private var windowBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color.clear,
                    Color.accentColor.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var activityDateRangeLabel: String {
        guard let summary = viewModel.summary else { return "" }
        let endDate = summary.generatedAt
        let startDate = Calendar.current.date(byAdding: .day, value: -13, to: endDate) ?? endDate
        return "\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func baselineProgressValue(_ condition: VisionDashboardWorkspaceSummary.ConditionSummary) -> String {
        guard let collected = condition.baselineDaysCollected,
              let required = condition.baselineDaysRequired else {
            return "--"
        }
        return "\(collected.formatted()) / \(required.formatted())"
    }

    private func numberString(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    private func hoursString(minutes: Double?) -> String {
        guard let minutes else { return "--" }
        let hours = minutes / 60.0
        return hours.formatted(.number.precision(.fractionLength(1)))
    }

    private func durationString(minutes: Double) -> String {
        durationString(seconds: minutes * 60.0)
    }

    private func durationString(seconds: TimeInterval) -> String {
        Self.durationFormatter.string(from: seconds) ?? "--"
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropAll]
        return formatter
    }()
}
