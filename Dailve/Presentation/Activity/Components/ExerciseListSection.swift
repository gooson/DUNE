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

    private let exerciseLibrary: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    init(
        workouts: [WorkoutSummary],
        exerciseRecords: [ExerciseRecord] = [],
        limit: Int = 5
    ) {
        self.workouts = workouts
        self.exerciseRecords = exerciseRecords
        self.limit = limit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section header
            HStack {
                Text("Recent Workouts")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if !items.isEmpty {
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
        .task(id: "\(workouts.count)-\(exerciseRecords.count)") {
            items = buildItems()
            rebuildRecordIndex()
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
            EmptyView()
        }
    }

    // MARK: - Build ExerciseListItem array

    private func buildItems() -> [ExerciseListItem] {
        let externalWorkouts = workouts.filteringAppDuplicates(against: exerciseRecords)

        var result: [ExerciseListItem] = []
        result.reserveCapacity(externalWorkouts.count + exerciseRecords.count)

        // HealthKit workouts
        for workout in externalWorkouts {
            result.append(ExerciseListItem(
                id: workout.id,
                type: workout.type,
                activityType: workout.activityType,
                duration: workout.duration,
                calories: workout.calories,
                distance: workout.distance,
                date: workout.date,
                source: .healthKit,
                heartRateAvg: workout.heartRateAvg,
                averagePace: workout.averagePace,
                elevationAscended: workout.elevationAscended,
                milestoneDistance: workout.milestoneDistance,
                isPersonalRecord: workout.isPersonalRecord,
                personalRecordTypes: workout.personalRecordTypes,
                workoutSummary: workout
            ))
        }

        // Manual records (with set data only, matching original behavior)
        let setRecords = exerciseRecords.filter(\.hasSetData)
        for record in setRecords {
            let definition = record.exerciseDefinitionID.flatMap {
                exerciseLibrary.exercise(byID: $0)
            }
            let localizedName = definition?.localizedName
            let activityType = definition?.resolvedActivityType
                ?? WorkoutActivityType.infer(from: record.exerciseType)
                ?? .other
            let hasHKLink = record.healthKitWorkoutID.map { !$0.isEmpty } ?? false
            result.append(ExerciseListItem(
                id: record.id.uuidString,
                type: record.exerciseType,
                localizedType: localizedName,
                activityType: activityType,
                duration: record.duration,
                calories: record.bestCalories,
                distance: record.distance,
                date: record.date,
                source: .manual,
                completedSets: record.completedSets,
                exerciseDefinitionID: record.exerciseDefinitionID,
                isLinkedToHealthKit: hasHKLink,
                primaryMuscles: record.primaryMuscles
            ))
        }

        return result.sorted { $0.date > $1.date }
    }

    // MARK: - Helpers

    private func rebuildRecordIndex() {
        recordsByID = Dictionary(uniqueKeysWithValues: exerciseRecords.map { ($0.id, $0) })
    }

    private func findRecord(for item: ExerciseListItem) -> ExerciseRecord? {
        guard let uuid = UUID(uuidString: item.id) else { return nil }
        return recordsByID[uuid]
    }
}
