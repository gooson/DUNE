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
        var externalWorkouts = healthKitWorkouts.filteringAppDuplicates(against: manualRecords)

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
            items.append(.fromManualRecord(record, library: exerciseLibrary))
        }

        allExercises = items.sorted { $0.date > $1.date }
    }

    func loadHealthKitWorkouts() async {
        isLoading = true
        hasMoreData = true
        oldestFetchedDate = nil

        do {
            let workouts = try await workoutService.fetchWorkouts(days: Self.pageSizeDays)
            healthKitWorkouts = workouts

            if let oldest = workouts.last?.date {
                oldestFetchedDate = oldest
            }
            // If fewer results than expected, no more data
            if workouts.isEmpty {
                hasMoreData = false
            }
        } catch {
            AppLogger.ui.error("Exercise data load failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Could not load workout data")
        }
        isLoading = false
    }

    /// Loads the next page of older workouts.
    func loadMoreWorkouts() async {
        guard !isLoadingMore, !isLoading, hasMoreData else { return }
        guard let cursor = oldestFetchedDate else {
            hasMoreData = false
            return
        }

        isLoadingMore = true
        let calendar = Calendar.current
        guard let pageStart = calendar.date(
            byAdding: .day, value: -Self.pageSizeDays, to: cursor
        ) else {
            isLoadingMore = false
            hasMoreData = false
            return
        }

        do {
            let moreWorkouts = try await workoutService.fetchWorkouts(
                start: pageStart, end: cursor
            )

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
        isLoadingMore = false
    }

}
