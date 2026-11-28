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

    init(workoutService: WorkoutQuerying? = nil, exerciseLibrary: ExerciseLibraryQuerying? = nil,
         personalRecordStore: PersonalRecordStore = .shared) {
        self.personalRecordStore = personalRecordStore
        self.workoutService = workoutService ?? WorkoutQueryService(manager: .shared)
        self.exerciseLibrary = exerciseLibrary ?? ExerciseLibraryService.shared
    }

    private(set) var allExercises: [ExerciseListItem] = []

    // Note: didSet fires separately per property. In practice, manualRecords and
    // healthKitWorkouts are not assigned in the same run loop tick (manualRecords
    // comes from @Query, healthKitWorkouts from async fetch), so double invalidation
    // does not occur. If batch updates are needed in the future, add an
    // updateData(workouts:records:) method that sets both before a single invalidation.
    private let personalRecordStore: PersonalRecordStore

    private func invalidateCache() {
        let tombstoned = DeletedWorkoutTombstoneStore.shared.tombstonedIDs

        // Set-backed records retain the established dedup preference.
        let setRecords = manualRecords.filter(\.hasSetData)
        let localRecords = healthKitWorkouts.localRecordsForDisplay(
            against: manualRecords,
            tombstonedIDs: tombstoned
        )
        var externalWorkouts = healthKitWorkouts.filteringAppDuplicates(
            against: setRecords,
            tombstonedIDs: tombstoned
        )

        // Detect milestones and personal records
        for i in externalWorkouts.indices {
            let prTypes = personalRecordStore.updateIfNewRecords(externalWorkouts[i])
            if !prTypes.isEmpty {
                // This list may discover the record before Activity or the HealthKit observer.
                _ = personalRecordStore.evaluateReward(for: externalWorkouts[i], newPRTypes: prTypes)
                externalWorkouts[i].isPersonalRecord = true
                externalWorkouts[i].personalRecordTypes = prTypes
            }
        }

        var items: [ExerciseListItem] = []
        items.reserveCapacity(externalWorkouts.count + localRecords.count)

        for workout in externalWorkouts {
            items.append(.fromWorkoutSummary(workout))
        }

        // Cardio records without sets are visible when their HealthKit counterpart is unavailable.
        for record in localRecords {
            items.append(.fromManualRecord(record, library: exerciseLibrary))
        }

        allExercises = items.sorted { $0.date > $1.date }
    }

    func loadHealthKitWorkouts(preservingLoadedPages: Bool = false) async {
        let requestID = beginLoadRequest()
        isLoading = true
        defer { finishLoadRequest(requestID) }

        let end = Date()
        let firstPageStart = Calendar.current.date(byAdding: .day, value: -Self.pageSizeDays, to: end)
        var olderCursor: Date?
        if preservingLoadedPages, let firstPageStart, let cursor = oldestFetchedDate, cursor < firstPageStart {
            olderCursor = cursor
        }

        do {
            let workouts: [WorkoutSummary]
            if let olderCursor {
                workouts = try await workoutService.fetchWorkouts(start: olderCursor, end: end)
            } else {
                workouts = try await workoutService.fetchWorkouts(days: Self.pageSizeDays)
            }
            guard isCurrentLoadRequest(requestID) else { return }
            healthKitWorkouts = workouts
            if olderCursor == nil {
                oldestFetchedDate = workouts.last?.date
                hasMoreData = !workouts.isEmpty
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
