import SwiftUI

/// Compact list of recent workouts with "See All" link.
/// Merges manual records and HealthKit workouts into a unified, date-sorted list
/// using ExerciseListItem and UnifiedWorkoutRow.
struct ExerciseListSection: View {
    let workouts: [WorkoutSummary]
    let exerciseRecords: [ExerciseRecord]
    let limit: Int

    @State private var items: [ExerciseListItem] = []
    @State private var recordsByID: [UUID: ExerciseRecord] = [:]

    private let exerciseLibrary: ExerciseLibraryQuerying

    init(
        workouts: [WorkoutSummary],
        exerciseRecords: [ExerciseRecord] = [],
        limit: Int = 5,
        exerciseLibrary: ExerciseLibraryQuerying = ExerciseLibraryService.shared
    ) {
        self.workouts = workouts
        self.exerciseRecords = exerciseRecords
        self.limit = limit
        self.exerciseLibrary = exerciseLibrary
    }

    /// Content-based task key — fires on any ID change, not just count.
    private var taskID: Int {
        var hasher = Hasher()
        for w in workouts { hasher.combine(w.id) }
        for r in exerciseRecords { hasher.combine(r.id) }
        return hasher.finalize()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if !items.isEmpty {
                HStack {
                    Spacer()

                    NavigationLink {
                        ExerciseView()
                    } label: {
                        Text("See All")
                            .font(.caption)
                            .foregroundStyle(DS.Color.activity)
                    }
                }
            }

            // Unified rows — date-sorted, limited
            ForEach(items.prefix(limit)) { item in
                NavigationLink {
                    destination(for: item)
                } label: {
                    UnifiedWorkoutRow(item: item, style: .compact)
                }
                .buttonStyle(.plain)
            }

            if items.isEmpty {
                InlineCard {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.secondary)
                        Text("No recent workouts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .task(id: taskID) {
            let (newItems, newIndex) = buildItemsAndIndex()
            guard !Task.isCancelled else { return }
            items = newItems
            recordsByID = newIndex
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destination(for item: ExerciseListItem) -> some View {
        if item.source == .manual, let record = findRecord(for: item) {
            ExerciseSessionDetailView(
                record: record,
                activityType: item.activityType,
                displayName: item.displayName
            )
        } else if item.source == .healthKit, let summary = item.workoutSummary {
            HealthKitWorkoutDetailView(workout: summary)
        } else {
            ContentUnavailableView(
                "Workout Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("This record may have been deleted.")
            )
        }
    }

    // MARK: - Build Items + Index Atomically

    private func buildItemsAndIndex() -> ([ExerciseListItem], [UUID: ExerciseRecord]) {
        let externalWorkouts = workouts.filteringAppDuplicates(against: exerciseRecords)

        var result: [ExerciseListItem] = []
        result.reserveCapacity(externalWorkouts.count + exerciseRecords.count)

        // HealthKit workouts
        for workout in externalWorkouts {
            result.append(.fromWorkoutSummary(workout))
        }

        // Manual records (with set data only, matching original behavior)
        let setRecords = exerciseRecords.filter(\.hasSetData)
        for record in setRecords {
            result.append(.fromManualRecord(record, library: exerciseLibrary))
        }

        let sorted = result.sorted { $0.date > $1.date }

        // Build index only for records with set data (safe merge for duplicate IDs)
        let index = Dictionary(
            setRecords.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )

        return (sorted, index)
    }

    // MARK: - Helpers

    private func findRecord(for item: ExerciseListItem) -> ExerciseRecord? {
        guard let uuid = UUID(uuidString: item.id) else { return nil }
        return recordsByID[uuid]
    }
}
