import Observation
import SwiftUI

/// ViewModel for the visionOS Train tab.
/// Fetches real workout data from HealthKit and computes per-muscle fatigue states.
@Observable
@MainActor
final class VisionTrainViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case unavailable(String)
        case failed(String)
    }

    var loadState: LoadState = .idle
    var fatigueStates: [MuscleFatigueState] = []
    var message: String?

    private let workoutService: WorkoutQuerying
    private let fatigueService: FatigueCalculating
    private let sharedHealthDataService: SharedHealthDataService?
    private let healthKitManager: any HealthKitManaging

    nonisolated init(
        sharedHealthDataService: SharedHealthDataService?,
        healthKitManager: any HealthKitManaging = HealthKitManager.shared,
        workoutService: WorkoutQuerying? = nil,
        fatigueService: FatigueCalculating = FatigueCalculationService()
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.healthKitManager = healthKitManager
        self.workoutService = workoutService ?? WorkoutQueryService(manager: .shared)
        self.fatigueService = fatigueService
    }

    func loadIfNeeded() async {
        guard fatigueStates.isEmpty, loadState != .loading else { return }
        await reload()
    }

    func reload() async {
        guard loadState != .loading else { return }
        loadState = .loading
        message = nil

        let healthKitAvailable = healthKitManager.isAvailable
        guard healthKitAvailable || sharedHealthDataService != nil else {
            fatigueStates = []
            loadState = .unavailable(
                String(localized: "Health data is not available on this device.")
            )
            return
        }

        if healthKitAvailable {
            do {
                try await healthKitManager.requestAuthorization()
            } catch {
                AppLogger.healthKit.error(
                    "Vision train authorization failed: \(error.localizedDescription)"
                )
            }
        }

        let snapshotTask = Task { await fetchSnapshot() }
        let workoutsTask = healthKitAvailable
            ? Task { await fetchWorkouts() }
            : nil

        let snapshotResult = await snapshotTask.value
        let workoutsResult = await workoutsTask?.value ?? FetchResult(value: [], message: nil)
        let snapshot = snapshotResult.value

        let snapshots = workoutsResult.value.compactMap(SpatialTrainingAnalyzer.snapshot(from:))

        let sleepModifier = computeSleepModifier(from: snapshot)
        let readinessModifier = computeReadinessModifier(from: snapshot)

        let compoundScores = fatigueService.computeCompoundFatigue(
            for: Array(MuscleGroup.allCases),
            from: snapshots,
            sleepModifier: sleepModifier,
            readinessModifier: readinessModifier,
            referenceDate: Date()
        )
        let scoreByMuscle = Dictionary(
            compoundScores.map { ($0.muscle, $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        let volumeByMuscle = snapshots.weeklyMuscleVolume(from: Date())

        fatigueStates = MuscleGroup.allCases.map { muscle in
            let muscleRecords = snapshots.filter {
                $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle)
            }
            let lastTrainedDate = muscleRecords.map(\.date).max()
            let hoursSinceLastTrained = lastTrainedDate.map { trainedDate in
                max(0, Date().timeIntervalSince(trainedDate) / 3600.0)
            }

            let recoveryPercent: Double
            if let hoursSinceLastTrained, muscle.recoveryHours > 0 {
                recoveryPercent = min(hoursSinceLastTrained / muscle.recoveryHours, 1.0)
            } else {
                recoveryPercent = 1.0
            }

            return MuscleFatigueState(
                muscle: muscle,
                lastTrainedDate: lastTrainedDate,
                hoursSinceLastTrained: hoursSinceLastTrained,
                weeklyVolume: volumeByMuscle[muscle] ?? 0,
                recoveryPercent: recoveryPercent,
                compoundScore: scoreByMuscle[muscle]
            )
        }

        let messages = [snapshotResult.message, workoutsResult.message].compactMap { $0 }
        message = messages.isEmpty ? nil : messages.joined(separator: "\n")

        let hasTrainingData = fatigueStates.contains { $0.lastTrainedDate != nil }
        if hasTrainingData {
            loadState = .ready
        } else {
            loadState = .unavailable(
                message ?? String(localized: "No recent training data found. Start a workout on your iPhone or Apple Watch.")
            )
        }
    }

    // MARK: - Private

    private func fetchSnapshot() async -> FetchResult<SharedHealthSnapshot?> {
        guard let sharedHealthDataService else {
            return FetchResult(value: nil, message: nil)
        }
        let snapshot = await sharedHealthDataService.fetchSnapshot()
        return FetchResult(value: snapshot, message: nil)
    }

    private func fetchWorkouts() async -> FetchResult<[WorkoutSummary]> {
        do {
            let workouts = try await workoutService.fetchWorkouts(days: 14)
            return FetchResult(value: workouts, message: nil)
        } catch {
            AppLogger.healthKit.error(
                "Vision train workout fetch failed: \(error.localizedDescription)"
            )
            return FetchResult(
                value: [],
                message: String(localized: "Recent workouts could not be loaded.")
            )
        }
    }

    private func computeSleepModifier(from snapshot: SharedHealthSnapshot?) -> Double {
        guard let summary = snapshot?.sleepSummaryForRecovery else { return 1.0 }
        let hours = summary.totalSleepMinutes / 60.0
        guard hours > 0, hours.isFinite else { return 1.0 }
        // 7h baseline: <7h penalizes recovery, >7h boosts it
        return (hours / 7.0).clamped(to: 0.5...1.25)
    }

    private func computeReadinessModifier(from snapshot: SharedHealthSnapshot?) -> Double {
        guard let score = snapshot?.conditionScore?.score else { return 1.0 }
        // 70-point baseline: lower condition score = slower recovery
        return (Double(score) / 70.0).clamped(to: 0.6...1.2)
    }
}

private struct FetchResult<Value: Sendable>: Sendable {
    let value: Value
    let message: String?
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
