import Foundation
import Observation

@Observable
@MainActor
final class ExerciseViewModel {
    var healthKitWorkouts: [WorkoutSummary] = [] { didSet { invalidateCache() } }
    var manualRecords: [ExerciseRecord] = [] { didSet { invalidateCache() } }
    var isLoading = false
    var isLoadingMore = false
    var hasMoreData = true
    var errorMessage: String?

    private let workoutService: WorkoutQuerying
    private let exerciseLibrary: ExerciseLibraryQuerying

    /// Number of days per page for incremental loading.
    private static let pageSizeDays = 30

    /// The earliest date already fetched (cursor for next page).
    private var oldestFetchedDate: Date?
    private var loadRequestID = 0

    init(workoutService: WorkoutQuerying? = nil, exerciseLibrary: ExerciseLibraryQuerying? = nil) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: .shared)
        self.exerciseLibrary = exerciseLibrary ?? ExerciseLibraryService.shared
    }

    private(set) var allExercises: [ExerciseListItem] = []

    // Note: didSet fires separately per property. In practice, manualRecords and
    // healthKitWorkouts are not assigned in the same run loop tick (manualRecords
    // comes from @Query, healthKitWorkouts from async fetch), so double invalidation
    // does not occur. If batch updates are needed in the future, add an
    // updateData(workouts:records:) method that sets both before a single invalidation.
    private let personalRecordStore = PersonalRecordStore.shared

    private func invalidateCache() {
        let tombstoned = DeletedWorkoutTombstoneStore.shared.tombstonedIDs

        // Only dedup HK workouts against records with meaningful content.
        // Empty stubs (0 duration, no calories, no sets) should not suppress
        // the richer HealthKit WorkoutSummary.
        let dedupRecords = manualRecords.filter(\.hasMeaningfulContent)
        var externalWorkouts = healthKitWorkouts.filteringAppDuplicates(
            against: dedupRecords,
            tombstonedIDs: tombstoned
        )

        // Detect milestones and personal records
        for i in externalWorkouts.indices {
            let prTypes = personalRecordStore.updateIfNewRecords(externalWorkouts[i])
            if !prTypes.isEmpty {
                externalWorkouts[i].isPersonalRecord = true
                externalWorkouts[i].personalRecordTypes = prTypes
            }
        }

        var items: [ExerciseListItem] = []
        items.reserveCapacity(externalWorkouts.count + manualRecords.count)

        for workout in externalWorkouts {
            items.append(.fromWorkoutSummary(workout))
        }

        for record in manualRecords {
            // Skip empty stubs that have a matching visible HealthKit workout.
            // Match by healthKitWorkoutID (primary) or type+date proximity (fallback).
            if !record.hasMeaningfulContent,
               hasMatchingVisibleWorkout(for: record, in: externalWorkouts) {
                continue
            }
            items.append(.fromManualRecord(record, library: exerciseLibrary))
        }

        allExercises = items.sorted { $0.date > $1.date }
    }

    /// Whether a visible HealthKit workout covers this empty stub record,
    /// making the stub redundant.
    private func hasMatchingVisibleWorkout(
        for record: ExerciseRecord,
        in workouts: [WorkoutSummary]
    ) -> Bool {
        // Primary: exact healthKitWorkoutID match
        if let hkID = record.healthKitWorkoutID, !hkID.isEmpty {
            return workouts.contains { $0.id == hkID }
        }
        // Fallback: type + date proximity (±2 min), same as dedup logic
        let recordActivity = WorkoutActivityType.infer(from: record.exerciseType)
        return workouts.contains { workout in
            guard abs(record.date.timeIntervalSince(workout.date)) < 120 else {
                return false
            }
            if record.exerciseType == workout.activityType.rawValue { return true }
            if let inferred = recordActivity, inferred == workout.activityType { return true }
            return false
        }
    }

    func loadHealthKitWorkouts() async {
        let requestID = beginLoadRequest()
        isLoading = true
        defer { finishLoadRequest(requestID) }

        hasMoreData = true
        oldestFetchedDate = nil

        do {
            let workouts = try await workoutService.fetchWorkouts(days: Self.pageSizeDays)
            guard isCurrentLoadRequest(requestID) else { return }
            healthKitWorkouts = workouts

            if let oldest = workouts.last?.date {
                oldestFetchedDate = oldest
            }
            // If fewer results than expected, no more data
            if workouts.isEmpty {
                hasMoreData = false
            }
        } catch {
            guard isCurrentLoadRequest(requestID) else { return }
            AppLogger.ui.error("Exercise data load failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Could not load workout data")
        }
    }

    /// Loads the next page of older workouts.
    func loadMoreWorkouts() async {
        guard !isLoadingMore, !isLoading, hasMoreData else { return }
        guard let cursor = oldestFetchedDate else {
            hasMoreData = false
            return
        }

        let requestID = loadRequestID
        isLoadingMore = true
        defer { isLoadingMore = false }
        let calendar = Calendar.current
        guard let pageStart = calendar.date(
            byAdding: .day, value: -Self.pageSizeDays, to: cursor
        ) else {
            hasMoreData = false
            return
        }

        do {
            let moreWorkouts = try await workoutService.fetchWorkouts(
                start: pageStart, end: cursor
            )

            guard isCurrentLoadRequest(requestID) else { return }

            if moreWorkouts.isEmpty {
                hasMoreData = false
            } else {
                // Deduplicate by ID before appending
                let existingIDs = Set(healthKitWorkouts.map(\.id))
                let newWorkouts = moreWorkouts.filter { !existingIDs.contains($0.id) }
                healthKitWorkouts.append(contentsOf: newWorkouts)

                if let oldest = moreWorkouts.last?.date {
                    oldestFetchedDate = oldest
                }
            }
        } catch {
            AppLogger.ui.error("Exercise load more failed: \(error.localizedDescription)")
        }
    }

    private func beginLoadRequest() -> Int {
        loadRequestID += 1
        return loadRequestID
    }

    private func isCurrentLoadRequest(_ requestID: Int) -> Bool {
        requestID == loadRequestID && !Task.isCancelled
    }

    private func finishLoadRequest(_ requestID: Int) {
        if requestID == loadRequestID {
            isLoading = false
        }
    }

}
