import SwiftUI

/// Watch exercise picker for Quick Start — starts a single-exercise workout without a template.
/// Uses `WatchConnectivityManager.exerciseLibrary` synced from iPhone.
struct QuickStartPickerView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var errorMessage: String?

    private var filteredExercises: [WatchExerciseInfo] {
        let library = connectivity.exerciseLibrary
        guard !searchText.isEmpty else { return library }
        return library.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if connectivity.exerciseLibrary.isEmpty {
                emptyState
            } else {
                exerciseList
            }
        }
        .navigationTitle("Quick Start")
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        List {
            ForEach(filteredExercises, id: \.id) { exercise in
                Button(action: { startQuickWorkout(exercise) }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text("\(exercise.defaultSets) sets · \(exercise.defaultReps ?? 10) reps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.right.inward")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No Exercises")
                .font(.headline)
            Text("Open the Dailve app\non your iPhone to sync")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Start Workout

    private func startQuickWorkout(_ exercise: WatchExerciseInfo) {
        let entry = TemplateEntry(
            exerciseDefinitionID: exercise.id,
            exerciseName: exercise.name,
            defaultSets: exercise.defaultSets,
            defaultReps: exercise.defaultReps ?? 10,
            defaultWeightKg: exercise.defaultWeightKg
        )
        let snapshot = WorkoutSessionTemplate(
            name: exercise.name,
            entries: [entry]
        )
        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startQuickWorkout(with: snapshot)
            } catch {
                errorMessage = "Failed to start: \(error.localizedDescription)"
            }
        }
    }
}
