import Foundation
import Testing
@testable import DUNE

private actor MockImmersiveSharedHealthDataService: SharedHealthDataService {
    private let snapshot: SharedHealthSnapshot
    private var fetchCount = 0

    init(snapshot: SharedHealthSnapshot) {
        self.snapshot = snapshot
    }

    func fetchSnapshot() async -> SharedHealthSnapshot {
        fetchCount += 1
        return snapshot
    }

    func invalidateCache() async {}

    func fetchCallCount() -> Int {
        fetchCount
    }
}

private actor MockImmersiveHealthKitManager: HealthKitManaging {
    nonisolated let isAvailable: Bool

    private let requestAuthorizationError: Error?
    private let saveError: Error?
    private var requestAuthorizationCount = 0
    private var savedSessions: [(start: Date, end: Date)] = []

    init(
        isAvailable: Bool,
        requestAuthorizationError: Error? = nil,
        saveError: Error? = nil
    ) {
        self.isAvailable = isAvailable
        self.requestAuthorizationError = requestAuthorizationError
        self.saveError = saveError
    }

    func requestAuthorization() async throws {
        requestAuthorizationCount += 1
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        savedSessions.append((start: start, end: end))
        if let saveError {
            throw saveError
        }
    }

    func requestCallCount() -> Int {
        requestAuthorizationCount
    }

    func savedSessionCount() -> Int {
        savedSessions.count
    }
}

private struct StubImmersiveRecoveryAnalyzer: ImmersiveRecoveryAnalyzing {
    let summary: ImmersiveRecoverySummary

    func buildSummary(from snapshot: SharedHealthSnapshot?, generatedAt: Date) -> ImmersiveRecoverySummary {
        summary
    }
}

private enum MockImmersiveError: Error {
    case failed
}

@Suite("VisionImmersiveExperienceViewModel")
@MainActor
struct VisionImmersiveExperienceViewModelTests {
    @Test("loadIfNeeded requests authorization and reuses the loaded summary")
    func loadIfNeededPopulatesSummaryOnce() async {
        let now = Date()
        let summary = makeSummary(generatedAt: now, message: "Shared snapshot service isn't connected.")
        let service = MockImmersiveSharedHealthDataService(snapshot: makeSnapshot(fetchedAt: now))
        let healthKitManager = MockImmersiveHealthKitManager(isAvailable: true)
        let viewModel = VisionImmersiveExperienceViewModel(
            sharedHealthDataService: service,
            healthKitManager: healthKitManager,
            analyzer: StubImmersiveRecoveryAnalyzer(summary: summary)
        )

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.summary == summary)
        #expect(viewModel.message == summary.message)
        #expect(await service.fetchCallCount() == 1)
        #expect(await healthKitManager.requestCallCount() == 1)
    }

    @Test("startRecoverySession switches mode and clears stale feedback")
    func startRecoverySessionSwitchesMode() {
        let viewModel = VisionImmersiveExperienceViewModel(
            sharedHealthDataService: nil,
            healthKitManager: MockImmersiveHealthKitManager(isAvailable: false),
            analyzer: StubImmersiveRecoveryAnalyzer(summary: makeSummary())
        )
        viewModel.sessionFeedback = "Old feedback"

        viewModel.startRecoverySession()

        #expect(viewModel.selectedMode == .recovery)
        #expect(viewModel.isRecoverySessionActive == true)
        #expect(viewModel.sessionFeedback == nil)
        #expect(viewModel.recoveryButtonTitle == String(localized: "Complete Session"))
        #expect(viewModel.recoveryStatusText.contains("0"))
    }

    @Test("completeRecoverySession saves mindful minutes when persistence is enabled")
    func completeRecoverySessionSavesMindfulMinutes() async {
        let healthKitManager = MockImmersiveHealthKitManager(isAvailable: false)
        let viewModel = VisionImmersiveExperienceViewModel(
            sharedHealthDataService: nil,
            healthKitManager: healthKitManager,
            analyzer: StubImmersiveRecoveryAnalyzer(summary: makeSummary(shouldPersistMindfulSession: true))
        )
        viewModel.summary = makeSummary(shouldPersistMindfulSession: true)
        viewModel.startRecoverySession()

        await viewModel.completeRecoverySession()

        #expect(await healthKitManager.savedSessionCount() == 1)
        #expect(viewModel.sessionFeedback == String(localized: "Mindful minutes saved to Health."))
        #expect(viewModel.isRecoverySessionActive == false)
        #expect(viewModel.isSavingMindfulSession == false)
        #expect(viewModel.recoveryButtonTitle == String(localized: "Start Session"))
    }

    @Test("completeRecoverySession reports Health save failures")
    func completeRecoverySessionReportsSaveFailure() async {
        let healthKitManager = MockImmersiveHealthKitManager(
            isAvailable: false,
            saveError: MockImmersiveError.failed
        )
        let viewModel = VisionImmersiveExperienceViewModel(
            sharedHealthDataService: nil,
            healthKitManager: healthKitManager,
            analyzer: StubImmersiveRecoveryAnalyzer(summary: makeSummary(shouldPersistMindfulSession: true))
        )
        viewModel.summary = makeSummary(shouldPersistMindfulSession: true)
        viewModel.startRecoverySession()

        await viewModel.completeRecoverySession()

        #expect(await healthKitManager.savedSessionCount() == 1)
        #expect(viewModel.sessionFeedback == String(localized: "Recovery session complete, but Health save didn't finish."))
        #expect(viewModel.isRecoverySessionActive == false)
    }

    @Test("completeRecoverySession skips Health save when persistence is disabled")
    func completeRecoverySessionSkipsSaveWhenPersistenceDisabled() async {
        let healthKitManager = MockImmersiveHealthKitManager(isAvailable: false)
        let viewModel = VisionImmersiveExperienceViewModel(
            sharedHealthDataService: nil,
            healthKitManager: healthKitManager,
            analyzer: StubImmersiveRecoveryAnalyzer(summary: makeSummary(shouldPersistMindfulSession: false))
        )
        viewModel.summary = makeSummary(shouldPersistMindfulSession: false)

        await viewModel.completeRecoverySession()

        #expect(await healthKitManager.savedSessionCount() == 0)
        #expect(viewModel.sessionFeedback == String(localized: "Recovery session complete."))
        #expect(viewModel.isRecoverySessionActive == false)
        #expect(viewModel.isSavingMindfulSession == false)
    }

    private func makeSummary(
        generatedAt: Date = Date(),
        shouldPersistMindfulSession: Bool = true,
        message: String? = nil
    ) -> ImmersiveRecoverySummary {
        ImmersiveRecoverySummary(
            atmosphere: .init(
                preset: .mist,
                score: 68,
                title: "Recovery Atmosphere",
                subtitle: "Fallback"
            ),
            recoverySession: .init(
                recommendation: .rebalance,
                title: "Reset your rhythm",
                subtitle: "Guided cadence",
                cadence: .init(inhaleSeconds: 4, inhaleHoldSeconds: 1, exhaleSeconds: 6, exhaleHoldSeconds: 1, cycles: 6),
                suggestedDurationMinutes: 5,
                shouldPersistMindfulSession: shouldPersistMindfulSession
            ),
            sleepJourney: .init(
                title: "Sleep Journey",
                subtitle: "Latest sleep",
                date: nil,
                isHistorical: false,
                totalMinutes: 90,
                segments: [
                    .init(stage: .core, durationMinutes: 90, startProgress: 0, endProgress: 1)
                ]
            ),
            generatedAt: generatedAt,
            message: message
        )
    }

    private func makeSnapshot(fetchedAt: Date) -> SharedHealthSnapshot {
        SharedHealthSnapshot(
            hrvSamples: [],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil,
            rhrCollection: [],
            todaySleepStages: [],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: [],
            conditionScore: nil,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: fetchedAt
        )
    }
}
