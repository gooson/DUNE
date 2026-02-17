import SwiftUI
import SwiftData

/// Main Watch screen: displays routines synced from iPhone via CloudKit.
struct RoutineListView: View {
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else {
                routineList
            }
        }
        .navigationTitle("Dailve")
    }

    private var routineList: some View {
        List(templates) { template in
            Button {
                startWorkout(with: template)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(template.exerciseEntries.count) exercises")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Routines")
                .font(.headline)
            Text("Create a routine\non your iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func startWorkout(with template: WorkoutTemplate) {
        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startWorkout(with: template)
            } catch {
                print("Failed to start workout: \(error.localizedDescription)")
            }
        }
    }
}
