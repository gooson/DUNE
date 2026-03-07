import Observation
import SwiftUI

@Observable
@MainActor
final class VisionSpatialViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case unavailable(String)
        case failed(String)
    }

    var loadState: LoadState = .idle
    var selectedScene: VisionSpatialSceneKind = .heartRateOrb
    var summary: SpatialTrainingSummary?
    var selectedMuscle: MuscleGroup?
    var latestHeartRateDate: Date?
    var message: String?

    private let sharedHealthDataService: SharedHealthDataService?
    private let heartRateService: HeartRateQuerying
    private let workoutService: WorkoutQuerying
    private let analyzer: SpatialTrainingAnalyzing
    private let healthKitManager: any HealthKitManaging

    init(
        sharedHealthDataService: SharedHealthDataService?,
        healthKitManager: any HealthKitManaging = HealthKitManager.shared,
        heartRateService: HeartRateQuerying? = nil,
        workoutService: WorkoutQuerying? = nil,
        analyzer: SpatialTrainingAnalyzing = SpatialTrainingAnalyzer()
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.healthKitManager = healthKitManager
        self.heartRateService = heartRateService ?? HeartRateQueryService(manager: .shared)
        self.workoutService = workoutService ?? WorkoutQueryService(manager: .shared)
        self.analyzer = analyzer
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
        guard healthKitAvailable || sharedHealthDataService != nil else {
            summary = analyzer.buildSummary(
                workouts: [],
                latestHeartRateBPM: nil,
                baselineRHR: nil,
                generatedAt: Date()
            )
            selectedMuscle = nil
            loadState = .unavailable(String(localized: "Health data isn't available in this environment."))
            return
        }

        if healthKitAvailable {
            do {
                try await healthKitManager.requestAuthorization()
            } catch {
                AppLogger.healthKit.error("Vision spatial authorization failed: \(error.localizedDescription)")
            }
        }

        let snapshotTask = Task { await fetchSnapshot() }
        let heartRateTask = healthKitAvailable ? Task { await fetchLatestHeartRate() } : nil
        let workoutsTask = healthKitAvailable ? Task { await fetchRecentWorkouts() } : nil

        let snapshotResult = await snapshotTask.value
        let heartRateResult = await heartRateTask?.value ?? VisionFetchResult<VitalSample?>(
            value: nil,
            message: nil
        )
        let workoutsResult = await workoutsTask?.value ?? VisionFetchResult<[WorkoutSummary]>(
            value: [],
            message: nil
        )

        let snapshot = snapshotResult.value
        let baselineRHR = snapshot?.effectiveRHR?.value
        latestHeartRateDate = heartRateResult.value?.date

        summary = analyzer.buildSummary(
            workouts: workoutsResult.value,
            latestHeartRateBPM: heartRateResult.value?.value,
            baselineRHR: baselineRHR,
            generatedAt: snapshot?.fetchedAt ?? Date()
        )

        if let summary {
            selectedMuscle = selectedMuscle
                ?? summary.featuredMuscles.first?.muscle
                ?? summary.muscleLoads.first(where: { $0.hasRecentLoad })?.muscle
        }

        let messages = [snapshotResult.message, heartRateResult.message, workoutsResult.message].compactMap { $0 }
        message = messages.isEmpty ? nil : messages.joined(separator: "\n")

        guard let summary else {
            loadState = .failed(String(localized: "Spatial data could not be loaded."))
            return
        }

        if summary.hasAnyData {
            loadState = .ready
        } else {
            loadState = .unavailable(
                message ?? String(localized: "No recent spatial health data is available yet.")
            )
        }
    }

    func selectMuscle(_ muscle: MuscleGroup) {
        selectedMuscle = muscle
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

    private func fetchLatestHeartRate() async -> VisionFetchResult<VitalSample?> {
        do {
            let sample = try await heartRateService.fetchLatestHeartRate(withinDays: 3)
            return VisionFetchResult(value: sample, message: nil)
        } catch {
            AppLogger.healthKit.error("Vision spatial HR fetch failed: \(error.localizedDescription)")
            return VisionFetchResult(
                value: nil,
                message: String(localized: "Latest heart rate is unavailable right now.")
            )
        }
    }

    private func fetchRecentWorkouts() async -> VisionFetchResult<[WorkoutSummary]> {
        do {
            let workouts = try await workoutService.fetchWorkouts(days: 14)
            return VisionFetchResult(value: workouts, message: nil)
        } catch {
            AppLogger.healthKit.error("Vision spatial workout fetch failed: \(error.localizedDescription)")
            return VisionFetchResult(
                value: [],
                message: String(localized: "Recent workouts could not be loaded.")
            )
        }
    }
}

