import SwiftUI

/// Manual records eligible for compact recent-list deduplication.
/// Compact list renders only records with set data, so dedup should use the same subset.
func recentListDedupRecords(from records: [ExerciseRecord]) -> [ExerciseRecord] {
    records.filter(\.hasSetData)
}

/// Compact list of recent workouts with "See All" link.
/// Merges manual records and HealthKit workouts into a unified, date-sorted list
/// using ExerciseListItem and UnifiedWorkoutRow.
struct ExerciseListSection: View {
    let workouts: [WorkoutSummary]
    let exerciseRecords: [ExerciseRecord]
    let limit: Int
    @State private var isShowingExerciseView = false

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

    private var builtContent: (items: [ExerciseListItem], recordsByID: [UUID: ExerciseRecord]) {
        buildItemsAndIndex()
    }

    var body: some View {
        let content = builtContent

        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Spacer()

                Button {
                    isShowingExerciseView = true
                } label: {
                    HStack(spacing: DS.Spacing.xxs) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption)
                    .foregroundStyle(DS.Color.activity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("activity-recent-seeall")
            }

            // Unified rows — date-sorted, limited
            ForEach(content.items.prefix(limit)) { item in
                NavigationLink {
                    destination(for: item, recordsByID: content.recordsByID)
                } label: {
                    UnifiedWorkoutRow(item: item, style: .compact)
                }
                .buttonStyle(.plain)
            }

            if content.items.isEmpty {
                InlineCard {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundStyle(DS.Color.textSecondary)
                        Text("No recent workouts")
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                        Spacer()
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isShowingExerciseView) {
            ExerciseView()
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destination(
        for item: ExerciseListItem,
        recordsByID: [UUID: ExerciseRecord]
    ) -> some View {
        if item.source == .manual, let record = findRecord(for: item, recordsByID: recordsByID) {
            ExerciseSessionDetailView(
                record: record,
                activityType: item.activityType,
                displayName: item.displayName,
                equipment: item.equipment
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
        // Keep dedup criteria aligned with rows that are actually rendered in this section.
        // Compact recent list intentionally shows only manual records with set data.
        // If we dedup against all manual records, cardio records without sets can hide
        // HealthKit workouts while not being rendered themselves.
        let setRecords = recentListDedupRecords(from: exerciseRecords)
        let externalWorkouts = workouts.filteringAppDuplicates(against: setRecords)

        var result: [ExerciseListItem] = []
        result.reserveCapacity(externalWorkouts.count + exerciseRecords.count)

        // HealthKit workouts
        for workout in externalWorkouts {
            result.append(.fromWorkoutSummary(workout))
        }

        // Manual records (with set data only, matching original behavior)
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

    private func findRecord(
        for item: ExerciseListItem,
        recordsByID: [UUID: ExerciseRecord]
    ) -> ExerciseRecord? {
        guard let uuid = UUID(uuidString: item.id) else { return nil }
        return recordsByID[uuid]
    }
}
