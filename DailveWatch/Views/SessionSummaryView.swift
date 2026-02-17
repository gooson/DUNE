import SwiftUI
import SwiftData

/// Post-workout summary showing total time, volume, sets, and HR.
struct SessionSummaryView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.modelContext) private var modelContext

    let startDate: Date
    let endDate: Date
    let completedSetsData: [[CompletedSetData]]
    let averageHR: Double
    let maxHR: Double
    let activeCalories: Double

    @State private var hasSaved = false
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)

                Text("Workout Complete")
                    .font(.headline)

                Divider()

                // Stats grid
                statsGrid

                Divider()

                // Exercise breakdown
                exerciseBreakdown

                // Done button
                Button {
                    saveAndDismiss()
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSaving)
                .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
        .navigationBarBackButtonHidden()
        .alert("Save Error", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Dismiss Without Saving") {
                workoutManager.reset()
            }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            statItem(title: "Duration", value: formattedDuration)
            statItem(title: "Volume", value: formattedVolume)
            statItem(title: "Sets", value: "\(totalSets)")
            statItem(title: "Avg HR", value: averageHR > 0 ? "\(Int(averageHR))" : "--")
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Exercise Breakdown

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(completedSetsData.enumerated()), id: \.offset) { index, sets in
                if !sets.isEmpty,
                   let template = workoutManager.templateSnapshot,
                   index < template.entries.count {
                    let entry = template.entries[index]
                    HStack {
                        Text(entry.exerciseName)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text("\(sets.count) sets")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        guard !isSaving, !hasSaved else { return }
        isSaving = true

        guard workoutManager.templateSnapshot != nil else {
            isSaving = false
            saveError = "Workout data could not be recovered. Sets cannot be saved."
            return
        }

        saveWorkoutRecords()
        hasSaved = true
        isSaving = false
        workoutManager.reset()
    }

    /// Persist ExerciseRecord + WorkoutSet to SwiftData for each exercise in the session.
    private func saveWorkoutRecords() {
        guard let template = workoutManager.templateSnapshot else { return }
        let sessionDuration = Swift.max(endDate.timeIntervalSince(startDate), 1)
        let activeExerciseCount = Double(Swift.max(completedSetsData.filter { !$0.isEmpty }.count, 1))

        for (exerciseIndex, setsData) in completedSetsData.enumerated() {
            guard exerciseIndex < template.entries.count, !setsData.isEmpty else { continue }

            let entry = template.entries[exerciseIndex]

            let record = ExerciseRecord(
                date: startDate,
                exerciseType: entry.exerciseName,
                duration: sessionDuration / activeExerciseCount,
                calories: activeCalories > 0 ? activeCalories / activeExerciseCount : nil,
                exerciseDefinitionID: entry.exerciseDefinitionID,
                calorieSource: activeCalories > 0 ? .healthKit : .manual
            )

            modelContext.insert(record)

            var workoutSets: [WorkoutSet] = []
            for setData in setsData {
                let workoutSet = WorkoutSet(
                    setNumber: setData.setNumber,
                    setType: .working,
                    weight: setData.weight,
                    reps: setData.reps,
                    isCompleted: true
                )
                workoutSet.exerciseRecord = record
                modelContext.insert(workoutSet)
                workoutSets.append(workoutSet)
            }
            record.sets = workoutSets
        }
    }

    // MARK: - Computed

    private var formattedDuration: String {
        let interval = endDate.timeIntervalSince(startDate)
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var totalSets: Int {
        completedSetsData.reduce(0) { $0 + $1.count }
    }

    private var formattedVolume: String {
        let volume = completedSetsData.flatMap { $0 }.reduce(0.0) { total, set in
            let w = set.weight ?? 0
            let r = Double(set.reps ?? 0)
            return total + (w * r)
        }
        if volume >= 1000 {
            return String(format: "%.1fk kg", volume / 1000)
        }
        return String(format: "%.0f kg", volume)
    }
}
