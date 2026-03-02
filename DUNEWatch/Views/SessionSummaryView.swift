import Foundation
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
            VStack(spacing: DS.Spacing.lg) {
                // Header
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(DS.Color.positive)

                Text("Workout Complete")
                    .font(DS.Typography.exerciseName)

                Divider()

                // Stats grid
                statsGrid

                if !workoutManager.isCardioMode {
                    Divider()

                    // Exercise breakdown (strength only)
                    exerciseBreakdown
                }

                // Done button
                Button {
                    saveAndDismiss()
                } label: {
                    Text(workoutManager.isFinalizingWorkout && !isSaving ? "Finishing..." : "Done")
                        .font(DS.Typography.tileTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.positive)
                .disabled(isSaving || workoutManager.isFinalizingWorkout)
                .padding(.top, DS.Spacing.md)
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .background { WatchWaveBackground(color: DS.Color.positive) }
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
        ], spacing: DS.Spacing.md) {
            statItem(title: "Duration", value: formattedDuration)

            if workoutManager.isCardioMode {
                statItem(title: "Distance", value: formattedDistance)
                statItem(title: "Avg Pace", value: workoutManager.formattedPace)
            } else {
                statItem(title: "Volume", value: formattedVolume)
                statItem(title: "Sets", value: totalSets.formattedWithSeparator)
            }

            statItem(title: "Avg HR", value: averageHR > 0 ? Int(averageHR).formattedWithSeparator : "--")
        }
    }

    private var formattedDistance: String {
        let km = workoutManager.distanceKm
        guard km > 0 else { return "--" }
        return String(format: "%.2f km", km)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value)
                .font(DS.Typography.tileSubtitle)
            Text(title)
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Exercise Breakdown

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(completedSetsData.enumerated()), id: \.offset) { index, sets in
                if !sets.isEmpty,
                   let template = workoutManager.templateSnapshot,
                   index < template.entries.count {
                    let entry = template.entries[index]
                    let volume = exerciseVolume(sets: sets)
                    HStack(spacing: DS.Spacing.sm) {
                        EquipmentIconView(equipment: entry.equipment, size: 16)
                            .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(entry.exerciseName)
                                .font(.caption2)
                                .lineLimit(1)
                            Text(volume > 0
                                ? "\(sets.count) sets · \(volume.formattedWithSeparator)kg"
                                : "\(sets.count) sets")
                                .font(DS.Typography.tinyLabel)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    /// Calculates total volume (weight × reps) for a set of completed sets.
    /// Capped at 50,000kg per Correction #85 (session-level physical upper bound).
    private func exerciseVolume(sets: [CompletedSetData]) -> Int {
        let vol = sets.reduce(0.0) { total, set in
            let w = set.weight ?? 0
            let r = Double(set.reps ?? 0)
            return total + (w * r)
        }
        guard vol.isFinite else { return 0 }
        return min(Int(vol.rounded()), 50_000)
    }

    // MARK: - Save

    private func saveAndDismiss() {
        guard !isSaving, !hasSaved else { return }
        isSaving = true
        Task {
            await saveAndDismissAsync()
        }
    }

    @MainActor
    private func saveAndDismissAsync() async {
        // Cardio sessions: HKWorkout is saved by HKLiveWorkoutBuilder — no SwiftData records to save.
        if workoutManager.isCardioMode {
            await workoutManager.waitForWorkoutFinalization()
            hasSaved = true
            isSaving = false
            workoutManager.reset()
            return
        }

        guard workoutManager.templateSnapshot != nil else {
            isSaving = false
            saveError = String(localized: "Workout data could not be recovered. Sets cannot be saved.")
            return
        }

        // Wait for HKWorkout finalization to reduce `healthKitWorkoutID = nil` race on Watch saves.
        await workoutManager.waitForWorkoutFinalization()
        saveWorkoutRecords(healthKitWorkoutID: workoutManager.healthKitWorkoutUUID)

        // Explicit save before reset — reset() triggers view transition
        // which can prevent SwiftData auto-save from flushing.
        do {
            try modelContext.save()
        } catch {
            saveError = String(localized: "Failed to save workout data. Please try again.")
            isSaving = false
            return
        }

        // Send workout data to iPhone via WatchConnectivity as backup
        sendWorkoutToPhone()
        recordExerciseUsage()

        hasSaved = true
        isSaving = false
        workoutManager.reset()
    }

    /// Persist ExerciseRecord + WorkoutSet to SwiftData for each exercise in the session.
    private func saveWorkoutRecords(healthKitWorkoutID: String?) {
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
                healthKitWorkoutID: healthKitWorkoutID,
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

    /// Send workout summary to iPhone via WatchConnectivity message.
    private func sendWorkoutToPhone() {
        guard let template = workoutManager.templateSnapshot else { return }

        // Build WatchWorkoutUpdate from completed data
        for (exerciseIndex, setsData) in completedSetsData.enumerated() {
            guard exerciseIndex < template.entries.count, !setsData.isEmpty else { continue }
            let entry = template.entries[exerciseIndex]

            let watchSets = setsData.map { set in
                WatchSetData(
                    setNumber: set.setNumber,
                    weight: set.weight,
                    reps: set.reps,
                    duration: nil,
                    isCompleted: true
                )
            }

            let update = WatchWorkoutUpdate(
                exerciseID: entry.exerciseDefinitionID,
                exerciseName: entry.exerciseName,
                completedSets: watchSets,
                startTime: startDate,
                endTime: endDate,
                heartRateSamples: []
            )

            WatchConnectivityManager.shared.sendWorkoutCompletion(update)
        }
    }

    /// Record usage for personalization in Quick Start popular ranking.
    private func recordExerciseUsage() {
        guard let template = workoutManager.templateSnapshot else { return }

        for (exerciseIndex, setsData) in completedSetsData.enumerated() {
            guard exerciseIndex < template.entries.count, !setsData.isEmpty else { continue }
            let entry = template.entries[exerciseIndex]
            RecentExerciseTracker.recordUsage(exerciseID: entry.exerciseDefinitionID)
            if let lastSet = setsData.last {
                RecentExerciseTracker.recordLatestSet(
                    exerciseID: entry.exerciseDefinitionID,
                    weight: lastSet.weight,
                    reps: lastSet.reps
                )
            }
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
        return "\(Int(volume.rounded()).formattedWithSeparator) kg"
    }
}


private enum WatchFormatterCache {
    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
}

extension Int {
    var formattedWithSeparator: String {
        WatchFormatterCache.integerFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    /// Formats weight with 1 decimal and thousand separator (e.g. "1,234.5").
    var formattedWeight: String {
        WatchFormatterCache.weightFormatter.string(from: NSNumber(value: self)) ?? String(format: "%.1f", self)
    }
}
