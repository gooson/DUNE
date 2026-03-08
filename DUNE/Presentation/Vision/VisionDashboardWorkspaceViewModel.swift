import Foundation
import Observation

enum VisionDashboardWindowKind: String, CaseIterable, Identifiable, Sendable, Hashable {
    case condition
    case activity
    case sleep
    case body

    var id: String { rawValue }

    var title: String {
        switch self {
        case .condition: String(localized: "Condition")
        case .activity: String(localized: "Activity")
        case .sleep: String(localized: "Sleep")
        case .body: String(localized: "Body")
        }
    }

    var systemImage: String {
        switch self {
        case .condition: "waveform.path.ecg"
        case .activity: "figure.run"
        case .sleep: "moon.stars.fill"
        case .body: "figure.stand"
        }
    }

    var windowID: String {
        switch self {
        case .condition: "dashboard-condition"
        case .activity: "dashboard-activity"
        case .sleep: "dashboard-sleep"
        case .body: "dashboard-body"
        }
    }
}

struct VisionDashboardWorkspaceSummary: Sendable {
    struct ConditionSummary: Sendable {
        let score: Int?
        let status: ConditionScore.Status?
        let narrative: String?
        let latestHRV: Double?
        let restingHeartRate: Double?
        let baselineDaysCollected: Int?
        let baselineDaysRequired: Int?
        let recentScores: [Int]

        var hasAnyData: Bool {
            score != nil
                || latestHRV != nil
                || restingHeartRate != nil
                || baselineDaysCollected != nil
        }
    }

    struct SleepSummary: Sendable {
        let score: Int?
        let totalMinutes: Double?
        let efficiency: Double?
        let deepSleepRatio: Double?
        let remSleepRatio: Double?
        let sampleDate: Date?
        let isHistorical: Bool

        var hasAnyData: Bool {
            score != nil || totalMinutes != nil || deepSleepRatio != nil || remSleepRatio != nil
        }
    }

    struct WorkoutHighlight: Sendable, Identifiable, Hashable {
        let id: String
        let title: String
        let duration: TimeInterval
        let date: Date
        let calories: Double?
    }

    struct ActivitySummary: Sendable {
        let workoutCount: Int
        let activeDays: Int
        let totalMinutes: Double
        let topWorkoutTitle: String?
        let topWorkoutMinutes: Double?
        let featuredMuscle: MuscleGroup?
        let featuredMuscleLoadUnits: Int?
        let featuredMuscleRecoveryPercent: Double?
        let recentWorkouts: [WorkoutHighlight]

        var hasAnyData: Bool {
            workoutCount > 0 || featuredMuscle != nil
        }
    }

    struct BodySummary: Sendable {
        let weightKg: Double?
        let bodyFatPercentage: Double?
        let leanBodyMassKg: Double?
        let sampleDate: Date?

        var hasAnyData: Bool {
            weightKg != nil || bodyFatPercentage != nil || leanBodyMassKg != nil
        }
    }

    let generatedAt: Date
    let condition: ConditionSummary
    let sleep: SleepSummary
    let activity: ActivitySummary
    let body: BodySummary

    var hasAnyData: Bool {
        condition.hasAnyData || sleep.hasAnyData || activity.hasAnyData || body.hasAnyData
    }
}

@Observable
@MainActor
final class VisionDashboardWorkspaceViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case unavailable(String)
        case failed(String)
    }

    var loadState: LoadState = .idle
    var summary: VisionDashboardWorkspaceSummary?
    var message: String?

    private let sharedHealthDataService: SharedHealthDataService?
    private let healthKitManager: HealthKitManaging
    private let workoutService: WorkoutQuerying
    private let bodyCompositionService: BodyCompositionQuerying
    private let sleepScoreUseCase: SleepScoreCalculating
    private let spatialAnalyzer: SpatialTrainingAnalyzing

    init(
        sharedHealthDataService: SharedHealthDataService?,
        healthKitManager: HealthKitManaging = HealthKitManager.shared,
        workoutService: WorkoutQuerying? = nil,
        bodyCompositionService: BodyCompositionQuerying? = nil,
        sleepScoreUseCase: SleepScoreCalculating = CalculateSleepScoreUseCase(),
        spatialAnalyzer: SpatialTrainingAnalyzing = SpatialTrainingAnalyzer()
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.healthKitManager = healthKitManager
        self.workoutService = workoutService ?? WorkoutQueryService(manager: .shared)
        self.bodyCompositionService = bodyCompositionService ?? BodyCompositionQueryService(manager: .shared)
        self.sleepScoreUseCase = sleepScoreUseCase
        self.spatialAnalyzer = spatialAnalyzer
    }

    func loadIfNeeded() async {
        guard summary == nil, loadState != .loading else { return }
        await reload()
    }

    func reload() async {
        guard loadState != .loading else { return }
        loadState = .loading
        message = nil

        let healthKitAvailable = healthKitManager.isAvailable
        if !healthKitAvailable, sharedHealthDataService == nil {
            let emptySummary = Self.buildSummary(
                snapshot: nil,
                workouts: [],
                weightSamples: [],
                bodyFatSamples: [],
                leanMassSamples: [],
                sleepScoreUseCase: sleepScoreUseCase,
                spatialAnalyzer: spatialAnalyzer,
                generatedAt: Date()
            )
            summary = emptySummary
            loadState = .unavailable(String(localized: "Health data isn't available in this environment."))
            return
        }

        if healthKitAvailable {
            do {
                try await healthKitManager.requestAuthorization()
            } catch {
                AppLogger.healthKit.error("Vision workspace authorization failed: \(error.localizedDescription)")
            }
        }

        async let snapshotTask = fetchSnapshot()
        async let workoutsTask = fetchRecentWorkouts()
        async let weightTask = fetchWeightSamples()
        async let bodyFatTask = fetchBodyFatSamples()
        async let leanMassTask = fetchLeanMassSamples()

        let (snapshotResult, workoutsResult, weightResult, bodyFatResult, leanMassResult) = await (
            snapshotTask,
            workoutsTask,
            weightTask,
            bodyFatTask,
            leanMassTask
        )

        let generatedAt = snapshotResult.value?.fetchedAt ?? Date()
        let resolvedSummary = Self.buildSummary(
            snapshot: snapshotResult.value,
            workouts: workoutsResult.value,
            weightSamples: weightResult.value,
            bodyFatSamples: bodyFatResult.value,
            leanMassSamples: leanMassResult.value,
            sleepScoreUseCase: sleepScoreUseCase,
            spatialAnalyzer: spatialAnalyzer,
            generatedAt: generatedAt
        )

        summary = resolvedSummary

        let messages = [
            snapshotResult.message,
            workoutsResult.message
        ].compactMap { $0 }
        message = messages.isEmpty ? nil : messages.joined(separator: "\n")

        if resolvedSummary.hasAnyData {
            loadState = .ready
        } else if let message {
            loadState = .unavailable(message)
        } else {
            loadState = .unavailable(String(localized: "No data available"))
        }
    }

    private func fetchSnapshot() async -> VisionFetchResult<SharedHealthSnapshot?> {
        guard let sharedHealthDataService else {
            return VisionFetchResult(
                value: nil,
                message: String(localized: "Shared snapshot service is not connected.")
            )
        }

        let snapshot = await sharedHealthDataService.fetchSnapshot()
        return VisionFetchResult(value: snapshot, message: nil)
    }

    private func fetchRecentWorkouts() async -> VisionFetchResult<[WorkoutSummary]> {
        do {
            let workouts = try await workoutService.fetchWorkouts(days: 14)
            return VisionFetchResult(value: workouts, message: nil)
        } catch {
            AppLogger.healthKit.error("Vision workspace workouts failed: \(error.localizedDescription)")
            return VisionFetchResult(
                value: [],
                message: String(localized: "Recent workouts could not be loaded.")
            )
        }
    }

    private func fetchWeightSamples() async -> VisionFetchResult<[BodyCompositionSample]> {
        do {
            let samples = try await bodyCompositionService.fetchWeight(days: 30)
            return VisionFetchResult(value: samples, message: nil)
        } catch {
            AppLogger.healthKit.error("Vision workspace weight failed: \(error.localizedDescription)")
            return VisionFetchResult(value: [], message: nil)
        }
    }

    private func fetchBodyFatSamples() async -> VisionFetchResult<[BodyCompositionSample]> {
        do {
            let samples = try await bodyCompositionService.fetchBodyFat(days: 30)
            return VisionFetchResult(value: samples, message: nil)
        } catch {
            AppLogger.healthKit.error("Vision workspace body fat failed: \(error.localizedDescription)")
            return VisionFetchResult(value: [], message: nil)
        }
    }

    private func fetchLeanMassSamples() async -> VisionFetchResult<[BodyCompositionSample]> {
        do {
            let samples = try await bodyCompositionService.fetchLeanBodyMass(days: 30)
            return VisionFetchResult(value: samples, message: nil)
        } catch {
            AppLogger.healthKit.error("Vision workspace lean mass failed: \(error.localizedDescription)")
            return VisionFetchResult(value: [], message: nil)
        }
    }

    private static func buildSummary(
        snapshot: SharedHealthSnapshot?,
        workouts: [WorkoutSummary],
        weightSamples: [BodyCompositionSample],
        bodyFatSamples: [BodyCompositionSample],
        leanMassSamples: [BodyCompositionSample],
        sleepScoreUseCase: SleepScoreCalculating,
        spatialAnalyzer: SpatialTrainingAnalyzing,
        generatedAt: Date
    ) -> VisionDashboardWorkspaceSummary {
        let conditionSummary = buildConditionSummary(from: snapshot)
        let sleepSummary = buildSleepSummary(from: snapshot, sleepScoreUseCase: sleepScoreUseCase)
        let activitySummary = buildActivitySummary(
            workouts: workouts,
            baselineRHR: snapshot?.effectiveRHR?.value,
            spatialAnalyzer: spatialAnalyzer,
            generatedAt: generatedAt
        )
        let bodySummary = buildBodySummary(
            weightSamples: weightSamples,
            bodyFatSamples: bodyFatSamples,
            leanMassSamples: leanMassSamples
        )

        return VisionDashboardWorkspaceSummary(
            generatedAt: generatedAt,
            condition: conditionSummary,
            sleep: sleepSummary,
            activity: activitySummary,
            body: bodySummary
        )
    }

    private static func buildConditionSummary(
        from snapshot: SharedHealthSnapshot?
    ) -> VisionDashboardWorkspaceSummary.ConditionSummary {
        let latestHRV = snapshot?.hrvSamples.max(by: { $0.date < $1.date })?.value
        return VisionDashboardWorkspaceSummary.ConditionSummary(
            score: snapshot?.conditionScore?.score,
            status: snapshot?.conditionScore?.status,
            narrative: snapshot?.conditionScore?.narrativeMessage,
            latestHRV: latestHRV,
            restingHeartRate: snapshot?.effectiveRHR?.value,
            baselineDaysCollected: snapshot?.baselineStatus?.daysCollected,
            baselineDaysRequired: snapshot?.baselineStatus?.daysRequired,
            recentScores: snapshot?.recentConditionScores
                .sorted(by: { $0.date < $1.date })
                .map(\.score) ?? []
        )
    }

    private static func buildSleepSummary(
        from snapshot: SharedHealthSnapshot?,
        sleepScoreUseCase: SleepScoreCalculating
    ) -> VisionDashboardWorkspaceSummary.SleepSummary {
        guard let sleepInput = snapshot?.sleepScoreInput else {
            return VisionDashboardWorkspaceSummary.SleepSummary(
                score: nil,
                totalMinutes: nil,
                efficiency: nil,
                deepSleepRatio: nil,
                remSleepRatio: nil,
                sampleDate: nil,
                isHistorical: false
            )
        }

        let output = sleepScoreUseCase.execute(input: .init(stages: sleepInput.stages))
        let totalSleepSeconds = sleepInput.stages
            .filter { $0.stage != .awake }
            .reduce(0.0) { $0 + $1.duration }
        let deepSleepSeconds = sleepInput.stages
            .filter { $0.stage == .deep }
            .reduce(0.0) { $0 + $1.duration }
        let remSleepSeconds = sleepInput.stages
            .filter { $0.stage == .rem }
            .reduce(0.0) { $0 + $1.duration }

        let deepSleepRatio = totalSleepSeconds > 0 ? deepSleepSeconds / totalSleepSeconds : nil
        let remSleepRatio = totalSleepSeconds > 0 ? remSleepSeconds / totalSleepSeconds : nil

        return VisionDashboardWorkspaceSummary.SleepSummary(
            score: output.score,
            totalMinutes: output.totalMinutes,
            efficiency: output.efficiency,
            deepSleepRatio: deepSleepRatio,
            remSleepRatio: remSleepRatio,
            sampleDate: sleepInput.date,
            isHistorical: sleepInput.isHistorical
        )
    }

    private static func buildActivitySummary(
        workouts: [WorkoutSummary],
        baselineRHR: Double?,
        spatialAnalyzer: SpatialTrainingAnalyzing,
        generatedAt: Date
    ) -> VisionDashboardWorkspaceSummary.ActivitySummary {
        let sortedWorkouts = workouts.sorted(by: { $0.date > $1.date })
        let totalMinutes = sortedWorkouts.reduce(0.0) { $0 + ($1.duration / 60.0) }

        let activeDays = Set(
            sortedWorkouts.map { Calendar.current.startOfDay(for: $0.date) }
        ).count

        let durationsByTitle = Dictionary(
            sortedWorkouts.map { ($0.type, $0.duration / 60.0) },
            uniquingKeysWith: +
        )
        let topWorkout = durationsByTitle.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key > rhs.key
        }

        let spatialSummary = spatialAnalyzer.buildSummary(
            workouts: sortedWorkouts,
            latestHeartRateBPM: nil,
            baselineRHR: baselineRHR,
            generatedAt: generatedAt
        )

        return VisionDashboardWorkspaceSummary.ActivitySummary(
            workoutCount: sortedWorkouts.count,
            activeDays: activeDays,
            totalMinutes: totalMinutes,
            topWorkoutTitle: topWorkout?.key,
            topWorkoutMinutes: topWorkout?.value,
            featuredMuscle: spatialSummary.featuredMuscles.first?.muscle,
            featuredMuscleLoadUnits: spatialSummary.featuredMuscles.first?.weeklyLoadUnits,
            featuredMuscleRecoveryPercent: spatialSummary.featuredMuscles.first?.recoveryPercent,
            recentWorkouts: Array(sortedWorkouts.prefix(3)).map {
                VisionDashboardWorkspaceSummary.WorkoutHighlight(
                    id: $0.id,
                    title: $0.type,
                    duration: $0.duration,
                    date: $0.date,
                    calories: $0.calories
                )
            }
        )
    }

    private static func buildBodySummary(
        weightSamples: [BodyCompositionSample],
        bodyFatSamples: [BodyCompositionSample],
        leanMassSamples: [BodyCompositionSample]
    ) -> VisionDashboardWorkspaceSummary.BodySummary {
        let latestWeight = weightSamples.max(by: { $0.date < $1.date })
        let latestBodyFat = bodyFatSamples.max(by: { $0.date < $1.date })
        let latestLeanMass = leanMassSamples.max(by: { $0.date < $1.date })
        let sampleDate = [latestWeight?.date, latestBodyFat?.date, latestLeanMass?.date]
            .compactMap { $0 }
            .max()

        return VisionDashboardWorkspaceSummary.BodySummary(
            weightKg: latestWeight?.value,
            bodyFatPercentage: latestBodyFat?.value,
            leanBodyMassKg: latestLeanMass?.value,
            sampleDate: sampleDate
        )
    }
}

