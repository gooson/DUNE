import Foundation
import SwiftUI
import SwiftData

/// Post-workout summary showing total time, volume, sets, and HR.
struct SessionSummaryView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.modelContext) private var modelContext
    @Query private var exerciseRecords: [ExerciseRecord]

    let startDate: Date
    let endDate: Date
    let completedSetsData: [[CompletedSetData]]
    let averageHR: Double
    let maxHR: Double
    let activeCalories: Double

    @State private var hasSaved = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var effort: Int = 5
    @State private var didInitializeEffort = false

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

                Divider()

                effortSection

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
        .onAppear {
            initializeSuggestedEffortIfNeeded()
        }
        .onChange(of: effortSuggestion?.suggestedEffort) { _, _ in
            initializeSuggestedEffortIfNeeded()
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
                if isStairMode {
                    statItem(title: "Floors Climbed", value: formattedFloors)
                } else {
                    statItem(title: "Distance", value: formattedDistance)
                    statItem(title: "Avg Pace", value: workoutManager.formattedPace)
                    if case .cardio(let activityType, _) = workoutManager.workoutMode,
                       activityType.isStepCountRelevant {
                        statItem(
                            title: "Steps",
                            value: workoutManager.steps > 0
                                ? Int(workoutManager.steps).formattedWithSeparator
                                : "--"
                        )
                    }
                }
            } else {
                statItem(title: "Volume", value: formattedVolume)
                statItem(title: "Sets", value: totalSets.formattedWithSeparator)
            }

            statItem(title: "Avg HR", value: averageHR > 0 ? Int(averageHR).formattedWithSeparator : "--")
        }
    }

    private var isStairMode: Bool {
        guard case .cardio(let type, _) = workoutManager.workoutMode else { return false }
        return type.isStairBased
    }

    private var formattedDistance: String {
        let km = workoutManager.distanceKm
        guard km > 0 else { return "--" }
        return String(format: "%.2f km", km)
    }

    private var formattedFloors: String {
        let floors = Int(workoutManager.floorsClimbed)
        guard floors > 0 else { return "--" }
        return "\(floors.formattedWithSeparator)"
    }

    private func statItem(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value)
                .font(DS.Typography.tileSubtitle)
            Text(title)
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(.secondary)
        }
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Color.positive)
                Text("Workout Effort")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let suggestion = effortSuggestion {
                Text("Recommended \(suggestion.suggestedEffort)/10 from recent history")
                    .font(DS.Typography.tinyLabel)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DS.Spacing.sm) {
                Text("\(effort)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("/10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            Slider(
                value: Binding(
                    get: { Double(effort) },
                    set: { newValue in
                        effort = Int(round(newValue))
                        didInitializeEffort = true
                    }
                ),
                in: 1...10,
                step: 1
            )
            .tint(DS.Color.positive)

            if let suggestion = effortSuggestion, !suggestion.recentEfforts.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Recent")
                        .font(DS.Typography.tinyLabel)
                        .foregroundStyle(.secondary)
                    ForEach(Array(suggestion.recentEfforts.prefix(5).enumerated()), id: \.offset) { index, value in
                        let isLatest = index == 0
                        Text("\(value)")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(isLatest ? DS.Color.positive : .secondary)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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
            saveCardioRecord(healthKitWorkoutID: workoutManager.healthKitWorkoutUUID)
            do {
                try modelContext.save()
            } catch {
                saveError = String(localized: "Failed to save workout data. Please try again.")
                isSaving = false
                return
            }
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

        // Wait for HKWorkout finalization (builder discard for strength).
        await workoutManager.waitForWorkoutFinalization()

        // Compute per-exercise allocation once (DRY — Correction #37, #148).
        let allocation = perExerciseAllocation()

        // Save individual HKWorkout per exercise and collect UUIDs (strength only).
        let perExerciseIDs: [Int: String]
        if workoutManager.workoutMode == .strength {
            perExerciseIDs = await saveIndividualHealthKitWorkouts(allocation: allocation)
        } else {
            perExerciseIDs = [:]
        }
        saveWorkoutRecords(perExerciseHealthKitIDs: perExerciseIDs, allocation: allocation)

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

    /// Per-exercise time/calorie allocation (single source of truth — Correction #37, #148).
    private func perExerciseAllocation() -> (duration: TimeInterval, calories: Double?) {
        let activeCount = Double(Swift.max(completedSetsData.filter { !$0.isEmpty }.count, 1))
        let sessionDuration = Swift.max(endDate.timeIntervalSince(startDate), 1)
        return (sessionDuration / activeCount, activeCalories > 0 ? activeCalories / activeCount : nil)
    }

    /// Creates individual HKWorkout per exercise via non-live HKWorkoutBuilder (parallel).
    /// Each exercise gets a sequential, non-overlapping time window to avoid HealthKit dedup.
    /// Returns a dictionary mapping exercise index → HealthKit workout UUID.
    private func saveIndividualHealthKitWorkouts(
        allocation: (duration: TimeInterval, calories: Double?)
    ) async -> [Int: String] {
        guard let template = workoutManager.templateSnapshot else { return [:] }
        let healthStore = workoutManager.healthStore

        // Build exercise entries with sequential offsets so time windows don't overlap.
        var activeIndex = 0
        var exerciseInputs: [(index: Int, name: String, start: Date)] = []
        for (index, setsData) in completedSetsData.enumerated() {
            guard index < template.entries.count, !setsData.isEmpty else { continue }
            let offsetStart = startDate.addingTimeInterval(allocation.duration * Double(activeIndex))
            exerciseInputs.append((index, template.entries[index].exerciseName, offsetStart))
            activeIndex += 1
        }

        // Parallel save via TaskGroup (avoids sequential N+1 round-trips).
        return await withTaskGroup(of: (Int, String?).self) { group in
            for input in exerciseInputs {
                group.addTask {
                    let uuid = await WatchWorkoutWriter.saveIndividualWorkout(
                        healthStore: healthStore,
                        exerciseName: input.name,
                        startDate: input.start,
                        duration: allocation.duration,
                        calories: allocation.calories
                    )
                    return (input.index, uuid)
                }
            }
            var ids: [Int: String] = [:]
            for await (index, uuid) in group {
                if let uuid { ids[index] = uuid }
            }
            return ids
        }
    }

    /// Persist ExerciseRecord + WorkoutSet to SwiftData for each exercise in the session.
    private func saveWorkoutRecords(
        perExerciseHealthKitIDs: [Int: String],
        allocation: (duration: TimeInterval, calories: Double?)
    ) {
        guard let template = workoutManager.templateSnapshot else { return }

        for (exerciseIndex, setsData) in completedSetsData.enumerated() {
            guard exerciseIndex < template.entries.count, !setsData.isEmpty else { continue }

            let entry = template.entries[exerciseIndex]

            let record = ExerciseRecord(
                date: startDate,
                exerciseType: entry.exerciseName,
                duration: allocation.duration,
                calories: allocation.calories,
                healthKitWorkoutID: perExerciseHealthKitIDs[exerciseIndex],
                exerciseDefinitionID: entry.exerciseDefinitionID,
                calorieSource: activeCalories > 0 ? .healthKit : .manual,
                rpe: effort
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

    private func saveCardioRecord(healthKitWorkoutID: String?) {
        let sessionDuration = Swift.max(endDate.timeIntervalSince(startDate), 1)
        let distanceKm = workoutManager.distanceKm

        var exerciseType = "Cardio"
        var exerciseDefinitionID: String?
        var primaryMuscles: [MuscleGroup] = []
        var secondaryMuscles: [MuscleGroup] = []

        if case .cardio(let activityType, _) = workoutManager.workoutMode {
            exerciseType = activityType.typeName
            exerciseDefinitionID = activityType.rawValue
            primaryMuscles = activityType.primaryMuscles
            secondaryMuscles = activityType.secondaryMuscles
        }

        let steps = workoutManager.steps
        let record = ExerciseRecord(
            date: startDate,
            exerciseType: exerciseType,
            duration: sessionDuration,
            calories: activeCalories > 0 ? activeCalories : nil,
            distance: distanceKm > 0 ? distanceKm : nil,
            stepCount: steps > 0 ? Int(steps) : nil,
            isFromHealthKit: true,
            healthKitWorkoutID: healthKitWorkoutID,
            exerciseDefinitionID: exerciseDefinitionID,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            calorieSource: activeCalories > 0 ? .healthKit : .manual,
            rpe: effort
        )
        modelContext.insert(record)
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
                    restDuration: set.restDuration,
                    isCompleted: true
                )
            }

            let update = WatchWorkoutUpdate(
                exerciseID: entry.exerciseDefinitionID,
                exerciseName: entry.exerciseName,
                completedSets: watchSets,
                startTime: startDate,
                endTime: endDate,
                heartRateSamples: [],
                rpe: effort
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
        let totalMinutes = Int(interval) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return String(localized: "\(hours)h \(mins)min")
        }
        return String(localized: "\(totalMinutes)min")
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

    private var currentExerciseIDs: Set<String> {
        guard let template = workoutManager.templateSnapshot else { return [] }
        var ids = Set<String>()
        for (index, sets) in completedSetsData.enumerated() where !sets.isEmpty {
            guard index < template.entries.count else { continue }
            ids.insert(template.entries[index].exerciseDefinitionID)
        }
        return ids
    }

    private var effortSuggestion: WatchEffortSuggestion? {
        let recentEfforts = recentEffortHistory
        guard let last = recentEfforts.first else { return nil }

        let average = Double(recentEfforts.reduce(0, +)) / Double(recentEfforts.count)
        let suggested: Int
        if recentEfforts.count >= 3, average.isFinite {
            suggested = Swift.max(1, Swift.min(10, Int(round(average))))
        } else {
            suggested = last
        }

        return WatchEffortSuggestion(
            suggestedEffort: suggested,
            recentEfforts: recentEfforts,
            averageEffort: average.isFinite ? average : nil
        )
    }

    private var recentEffortHistory: [Int] {
        let ids = currentExerciseIDs
        let scopedRecords = exerciseRecords.filter { record in
            guard let effort = record.rpe, (1...10).contains(effort) else { return false }
            if ids.isEmpty {
                // Cardio sessions have no template IDs. Prefer activity-matched history,
                // then gracefully fallback for recovered/unknown sessions.
                guard case .cardio(let activityType, _) = workoutManager.workoutMode else { return true }
                let cardioID = activityType.rawValue
                let cardioName = activityType.typeName
                if let definitionID = record.exerciseDefinitionID {
                    return definitionID == cardioID
                }
                return record.exerciseType == cardioID || record.exerciseType == cardioName
            }
            guard let id = record.exerciseDefinitionID else { return false }
            return ids.contains(id)
        }

        return Array(
            scopedRecords
                .sorted { $0.date > $1.date }
                .compactMap(\.rpe)
                .prefix(5)
        )
    }

    private func initializeSuggestedEffortIfNeeded() {
        guard !didInitializeEffort, let suggested = effortSuggestion?.suggestedEffort else { return }
        effort = suggested
        didInitializeEffort = true
    }
}

private struct WatchEffortSuggestion {
    let suggestedEffort: Int
    let recentEfforts: [Int]
    let averageEffort: Double?
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
