import SwiftUI
import SwiftData
import WatchKit

/// Post-workout summary showing total time, volume, sets, and HR.
struct SessionSummaryView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var exerciseRecords: [ExerciseRecord]

    let startDate: Date
    let endDate: Date
    let completedSetsData: [[CompletedSetData]]
    let averageHR: Double
    let maxHR: Double
    let activeCalories: Double

    @State private var hasSaved = false
    @State private var isSaving = false
    @State private var didStartAutomaticSave = false
    @State private var saveError: String?
    @State private var didCreateRecords = false
    @State private var savedRecords: [ExerciseRecord] = []
    @State private var savedEffort: Int?
    @State private var didSendCompletionUpdate = false
    @State private var effort: Int = WatchEffortInputPolicy.defaultEffort
    @State private var didInitializeEffort = false
    @State private var lastEffortHapticDate: Date = .distantPast
    @State private var showEffortInput = false
    @State private var didPresentEffortInput = false
    @State private var effortInputAutoCloseTask: Task<Void, Never>?

    /// Auto-dismiss effort input after a short period of inactivity.
    private let effortInputAutoCloseDelay: Duration = .seconds(12)

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DS.Color.positive)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Workout Complete")
                            .font(DS.Typography.exerciseName)
                        if saveError != nil {
                            Text("Save Error")
                                .foregroundStyle(DS.Color.negative)
                                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummarySaveStatus)
                        } else if hasSaved {
                            Text("Saved")
                                .foregroundStyle(DS.Color.positive)
                                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummarySaveStatus)
                        } else if isSaving || workoutManager.isFinalizingWorkout {
                            Text("Saving...")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummarySaveStatus)
                        }
                    }
                    .font(.caption2)
                }

                Divider()

                // Stats grid
                statsGrid

                Divider()

                Button {
                    showEffortInput = true
                } label: {
                    effortSummaryRow
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummaryEffortButton)

                if !workoutManager.isCardioMode {
                    Divider()

                    // Exercise breakdown (strength only)
                    exerciseBreakdown
                }

            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                finishSummary()
            } label: {
                Text("Done")
                    .font(DS.Typography.tileTitle)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.positive)
            .disabled(isSaving || workoutManager.isFinalizingWorkout)
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummaryDoneButton)
            .padding(.horizontal, DS.Spacing.xs)
        }
        .background { WatchWaveBackground(color: DS.Color.positive) }
        .navigationBarBackButtonHidden()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummaryScreen)
        .alert("Save Error", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Retry") {
                retrySave()
            }
            if hasSaved {
                Button("Done") { workoutManager.reset() }
            } else {
                Button("Dismiss Without Saving") { workoutManager.reset() }
            }
        } message: {
            Text(saveError ?? "")
        }
        .sheet(isPresented: $showEffortInput) {
            SessionEffortInputSheet(
                effort: Binding(
                    get: { effort },
                    set: { newValue in
                        updateEffort(newValue)
                    }
                ),
                suggestion: effortSuggestion,
                onClose: {
                    cancelEffortInputAutoCloseTimer()
                    showEffortInput = false
                }
            )
        }
        .onAppear {
            initializeSuggestedEffortIfNeeded()
            if !didPresentEffortInput {
                didPresentEffortInput = true
                showEffortInput = true
            }
            if !didStartAutomaticSave {
                didStartAutomaticSave = true
                startSaving()
            }
        }
        .onChange(of: effortSuggestion?.suggestedEffort) { _, _ in
            initializeSuggestedEffortIfNeeded()
        }
        .onChange(of: showEffortInput) { _, isPresented in
            if isPresented {
                startEffortInputAutoCloseTimer()
            } else {
                cancelEffortInputAutoCloseTimer()
                if persistEffortIfNeeded() { sendCompletionUpdateIfNeeded() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                if persistEffortIfNeeded() { sendCompletionUpdateIfNeeded() }
            }
        }
        .onDisappear {
            cancelEffortInputAutoCloseTimer()
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
                if workoutManager.supportsMachineLevel {
                    statItem(title: "Avg Level", value: workoutManager.formattedAverageMachineLevel)
                    statItem(title: "Max Level", value: workoutManager.formattedMaxMachineLevel)
                    if isStairMode {
                        statItem(title: "Floors Climbed", value: formattedFloors)
                    }
                } else if isStairMode {
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

            statItem(title: "Calories", value: formattedCalories)
            statItem(title: "Avg HR", value: averageHR > 0 ? Int(averageHR).formattedWithSeparator : "--")
        }
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummaryStatsGrid)
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

    private var formattedCalories: String {
        if activeCalories > 0 {
            return "\(Int(activeCalories).formattedWithSeparator) kcal"
        }
        if let met = estimatedSessionCaloriesMET(), met > 0 {
            return "~\(Int(met).formattedWithSeparator) kcal"
        }
        return "--"
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

    private var effortSummaryRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Workout Intensity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(effort)/10 · \(WatchEffortInputPolicy.descriptor(for: effort))")
                    .font(DS.Typography.tinyLabel)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("\(effort)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DS.Color.positive)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func updateEffort(_ newEffort: Int) {
        restartEffortInputAutoCloseTimerIfNeeded()
        guard newEffort != effort else { return }
        effort = newEffort
        didInitializeEffort = true
        playEffortHapticIfNeeded()
    }

    private func restartEffortInputAutoCloseTimerIfNeeded() {
        guard showEffortInput else { return }
        startEffortInputAutoCloseTimer()
    }

    private func startEffortInputAutoCloseTimer() {
        cancelEffortInputAutoCloseTimer()
        effortInputAutoCloseTask = Task { @MainActor in
            try? await Task.sleep(for: effortInputAutoCloseDelay)
            guard !Task.isCancelled, showEffortInput else { return }
            showEffortInput = false
        }
    }

    private func cancelEffortInputAutoCloseTimer() {
        effortInputAutoCloseTask?.cancel()
        effortInputAutoCloseTask = nil
    }

    private func playEffortHapticIfNeeded() {
        let now = Date()
        guard WatchEffortInputPolicy.shouldPlayHaptic(lastHapticDate: lastEffortHapticDate, now: now) else {
            return
        }
        lastEffortHapticDate = now
        WKInterfaceDevice.current().play(.click)
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
                    let totalDuration = exerciseTotalDuration(sets: sets)
                    HStack(spacing: DS.Spacing.sm) {
                        EquipmentIconView(equipment: entry.equipment, size: 16)
                            .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(entry.exerciseName)
                                .font(.caption2)
                                .lineLimit(1)
                            Text(exerciseSummaryText(
                                setCount: sets.count,
                                volume: volume,
                                totalDurationMinutes: totalDuration
                            ))
                                .font(DS.Typography.tinyLabel)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummaryExerciseBreakdown)
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

    /// Calculates total duration in minutes for duration-based exercises.
    private func exerciseTotalDuration(sets: [CompletedSetData]) -> Int {
        let totalSeconds = sets.reduce(0.0) { total, set in
            total + (set.duration ?? 0)
        }
        return Int((totalSeconds / 60).rounded())
    }

    /// Builds summary text for exercise breakdown: prefers duration for duration-based, volume for weight-based.
    private func exerciseSummaryText(setCount: Int, volume: Int, totalDurationMinutes: Int) -> String {
        if totalDurationMinutes > 0 {
            return String(localized: "\(setCount) sets · \(totalDurationMinutes)min")
        } else if volume > 0 {
            return String(localized: "\(setCount) sets · \(volume.formattedWithSeparator)kg")
        } else {
            return String(localized: "\(setCount) sets")
        }
    }

    // MARK: - Save

    private func finishSummary() {
        if hasSaved {
            if persistEffortIfNeeded() {
                sendCompletionUpdateIfNeeded()
                workoutManager.reset()
            }
            return
        }
        startSaving(dismissOnSuccess: true)
    }

    private func retrySave() {
        saveError = nil
        if hasSaved {
            _ = persistEffortIfNeeded()
        } else {
            startSaving()
        }
    }

    private func startSaving(dismissOnSuccess: Bool = false) {
        guard !isSaving, !hasSaved else { return }
        saveError = nil
        isSaving = true
        Task {
            await saveSession(dismissOnSuccess: dismissOnSuccess)
        }
    }

    @MainActor
    private func saveSession(dismissOnSuccess: Bool) async {
        // Cardio HKWorkout is finalized by HKLiveWorkoutBuilder before its record is saved.
        if workoutManager.isCardioMode {
            await workoutManager.waitForWorkoutFinalization()
            if !didCreateRecords {
                savedRecords = [saveCardioRecord(healthKitWorkoutID: workoutManager.healthKitWorkoutUUID)]
                didCreateRecords = true
            }
            savedRecords.forEach { $0.rpe = effort }
            do {
                try modelContext.save()
            } catch {
                saveError = String(localized: "Failed to save workout data. Please try again.")
                isSaving = false
                return
            }
            hasSaved = true
            savedEffort = effort
            saveError = nil
            isSaving = false
            if dismissOnSuccess { workoutManager.reset() }
            return
        }

        guard workoutManager.templateSnapshot != nil else {
            isSaving = false
            saveError = String(localized: "Workout data could not be recovered. Sets cannot be saved.")
            return
        }

        // Wait for HKWorkout finalization (builder discard for strength).
        await workoutManager.waitForWorkoutFinalization()

        if !didCreateRecords {
            // Cache the created workouts and records so a SwiftData retry cannot duplicate them.
            let allocation = perExerciseAllocation()
            let perExerciseIDs = workoutManager.workoutMode == .strength
                ? await saveIndividualHealthKitWorkouts(allocation: allocation)
                : [:]
            savedRecords = saveWorkoutRecords(perExerciseHealthKitIDs: perExerciseIDs, allocation: allocation)
            didCreateRecords = true
        }
        savedRecords.forEach { $0.rpe = effort }

        // Explicit save before reset — reset() triggers view transition
        // which can prevent SwiftData auto-save from flushing.
        do {
            try modelContext.save()
        } catch {
            saveError = String(localized: "Failed to save workout data. Please try again.")
            isSaving = false
            return
        }

        recordExerciseUsage()

        hasSaved = true
        savedEffort = effort
        saveError = nil
        isSaving = false
        if !showEffortInput { sendCompletionUpdateIfNeeded() }
        if dismissOnSuccess { workoutManager.reset() }
    }

    /// Send the first backup after the effort prompt closes, so it includes the chosen rating.
    private func sendCompletionUpdateIfNeeded() {
        guard hasSaved, !workoutManager.isCardioMode, !didSendCompletionUpdate else { return }
        for record in savedRecords {
            WatchConnectivityManager.shared.sendWorkoutCompletion(
                WatchWorkoutRecordBuilder.makeUpdate(from: record)
            )
        }
        didSendCompletionUpdate = true
    }

    /// An effort edit may happen after automatic save; keep the persisted record in sync.
    @discardableResult
    private func persistEffortIfNeeded() -> Bool {
        guard hasSaved, savedEffort != effort else { return true }
        savedRecords.forEach { $0.rpe = effort }
        do {
            try modelContext.save()
        } catch {
            saveError = String(localized: "Failed to save workout data. Please try again.")
            return false
        }
        savedEffort = effort
        saveError = nil
        if !workoutManager.isCardioMode {
            for record in savedRecords {
                WatchConnectivityManager.shared.sendWorkoutCompletion(
                    WatchWorkoutRecordBuilder.makeUpdate(from: record)
                )
            }
        }
        return true
    }

    /// Per-exercise time/calorie allocation (single source of truth — Correction #37, #148).
    private func perExerciseAllocation() -> (duration: TimeInterval, calories: Double?, calorieSource: CalorieSource) {
        let activeCount = Double(Swift.max(completedSetsData.filter { !$0.isEmpty }.count, 1))
        let sessionDuration = Swift.max(workoutManager.activeElapsedTime(at: endDate), 1)
        let perExerciseDuration = sessionDuration / activeCount

        // Prefer HK active calories when available (typically cardio).
        if activeCalories > 0 {
            return (perExerciseDuration, activeCalories / activeCount, .healthKit)
        }

        // MET-based fallback for strength workouts where HK provides ~0 calories.
        if let metCalories = estimatedSessionCaloriesMET(), metCalories > 0 {
            return (perExerciseDuration, metCalories / activeCount, .met)
        }

        return (perExerciseDuration, nil, .manual)
    }

    /// MET-based calorie estimation using the average metValue of active exercises.
    /// Delegates to CalorieEstimationService for the MET formula (single source of truth with iOS).
    private func estimatedSessionCaloriesMET() -> Double? {
        guard let template = workoutManager.templateSnapshot else { return nil }
        let exerciseLibrary = WatchConnectivityManager.shared.exerciseLibrary
        let libraryByID = Dictionary(
            exerciseLibrary.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Collect MET values for active exercises (those with completed sets).
        var metValues: [Double] = []
        for (index, setsData) in completedSetsData.enumerated() {
            guard index < template.entries.count, !setsData.isEmpty else { continue }
            let entry = template.entries[index]
            if let met = libraryByID[entry.exerciseDefinitionID]?.metValue, met > 0 {
                metValues.append(met)
            }
        }
        guard !metValues.isEmpty else { return nil }

        let averageMET = metValues.reduce(0, +) / Double(metValues.count)
        let sessionDuration = Swift.max(workoutManager.activeElapsedTime(at: endDate), 1)
        let totalSetsCount = completedSetsData.reduce(0) { $0 + $1.count }
        let estimatedRestSeconds = Double(Swift.max(totalSetsCount - 1, 0))
            * WatchConnectivityManager.shared.globalRestSeconds

        return CalorieEstimationService().estimate(
            metValue: averageMET,
            bodyWeightKg: CalorieEstimationService.defaultBodyWeightKg,
            durationSeconds: sessionDuration,
            restSeconds: estimatedRestSeconds
        )
    }

    /// Creates individual HKWorkout per exercise via non-live HKWorkoutBuilder (parallel).
    /// Each exercise gets a sequential, non-overlapping time window to avoid HealthKit dedup.
    /// Returns a dictionary mapping exercise index → HealthKit workout UUID.
    private func saveIndividualHealthKitWorkouts(
        allocation: (duration: TimeInterval, calories: Double?, calorieSource: CalorieSource)
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
        allocation: (duration: TimeInterval, calories: Double?, calorieSource: CalorieSource)
    ) -> [ExerciseRecord] {
        guard let template = workoutManager.templateSnapshot else { return [] }
        var records: [ExerciseRecord] = []

        for (exerciseIndex, setsData) in completedSetsData.enumerated() {
            guard exerciseIndex < template.entries.count, !setsData.isEmpty else { continue }
            let entry = template.entries[exerciseIndex]
            let record = WatchWorkoutRecordBuilder.makeRecord(
                exerciseName: entry.exerciseName,
                exerciseDefinitionID: entry.exerciseDefinitionID,
                sets: setsData,
                startDate: startDate,
                duration: allocation.duration,
                calories: allocation.calories,
                calorieSource: allocation.calorieSource,
                effort: effort,
                inputType: WatchConnectivityManager.shared.exerciseInfo(for: entry.exerciseDefinitionID)
                    .flatMap { ExerciseInputType(rawValue: $0.inputType) }
                    ?? TemplateExerciseProfile.normalizedInputTypeRaw(entry.inputTypeRaw)
                        .flatMap(ExerciseInputType.init(rawValue:))
                    ?? .setsRepsWeight,
                history: exerciseRecords,
                plannedSetCount: workoutManager.plannedSetCount(for: exerciseIndex),
                healthKitWorkoutID: perExerciseHealthKitIDs[exerciseIndex]
            )
            modelContext.insert(record)
            records.append(record)
        }
        return records
    }

    private func saveCardioRecord(healthKitWorkoutID: String?) -> ExerciseRecord {
        let sessionDuration = Swift.max(workoutManager.activeElapsedTime(at: endDate), 1)
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
        let pace = workoutManager.currentPace
        let floors = workoutManager.floorsClimbed
        let record = ExerciseRecord(
            date: startDate,
            exerciseType: exerciseType,
            duration: sessionDuration,
            calories: activeCalories > 0 ? activeCalories : nil,
            distance: distanceKm > 0 ? distanceKm : nil,
            stepCount: steps > 0 ? Int(steps) : nil,
            averagePaceSecondsPerKm: pace > 0 ? pace : nil,
            floorsAscended: floors > 0 ? floors : nil,
            cardioMachineLevelAverage: workoutManager.averageMachineLevel,
            cardioMachineLevelMax: workoutManager.maxMachineLevel,
            isFromHealthKit: true,
            healthKitWorkoutID: healthKitWorkoutID,
            exerciseDefinitionID: exerciseDefinitionID,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            calorieSource: activeCalories > 0 ? .healthKit : .manual,
            rpe: effort,
            autoIntensityRaw: workoutManager.cardioMachineAutoIntensityRaw
        )
        modelContext.insert(record)
        return record
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
            RecentExerciseTracker.recordLatestProcedure(
                exerciseID: entry.exerciseDefinitionID,
                sets: setsData.map {
                    WatchProcedureSetSnapshot(
                        setNumber: $0.setNumber,
                        weight: $0.weight,
                        reps: $0.reps,
                        plannedReps: $0.plannedReps,
                        rpe: $0.rpe,
                        rpeSourceRaw: $0.rpeSourceRaw,
                        setTypeRaw: $0.setTypeRaw ?? SetType.working.rawValue,
                        plannedSetCount: workoutManager.plannedSetCount(for: exerciseIndex)
                    )
                }
            )
        }
    }

    // MARK: - Computed

    private var formattedDuration: String {
        let interval = workoutManager.activeElapsedTime(at: endDate)
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
        effort = WatchEffortInputPolicy.clampedEffort(suggested)
        didInitializeEffort = true
    }
}

private struct WatchEffortSuggestion {
    let suggestedEffort: Int
    let recentEfforts: [Int]
    let averageEffort: Double?
}

private struct SessionEffortInputSheet: View {
    @Binding var effort: Int
    let suggestion: WatchEffortSuggestion?
    var onClose: () -> Void

    @FocusState private var isCrownFocused: Bool
    @State private var crownFocusTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Color.positive)
                Text("Workout Intensity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let suggestion {
                Text("Recommended \(suggestion.suggestedEffort)/10 from recent history")
                    .font(DS.Typography.tinyLabel)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DS.Spacing.sm) {
                Text("\(effort)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("/10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(WatchEffortInputPolicy.descriptor(for: effort))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(effort) },
                    set: { newValue in
                        let clamped = WatchEffortInputPolicy.clampedEffort(Int(round(newValue)))
                        effort = clamped
                    }
                ),
                in: Double(WatchEffortInputPolicy.minimumEffort)...Double(WatchEffortInputPolicy.maximumEffort),
                step: 1
            )
            .tint(DS.Color.positive)

            if let suggestion, !suggestion.recentEfforts.isEmpty {
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
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .focusable(true)
        .focused($isCrownFocused)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummaryEffortSheet)
        .digitalCrownRotation(
            Binding(
                get: { Double(effort) },
                set: { newValue in
                    let clamped = WatchEffortInputPolicy.clampedEffort(Int(round(newValue)))
                    effort = clamped
                }
            ),
            from: Double(WatchEffortInputPolicy.minimumEffort),
            through: Double(WatchEffortInputPolicy.maximumEffort),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onClose()
                }
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionSummaryEffortDoneButton)
            }
        }
        .onAppear {
            crownFocusTask?.cancel()
            crownFocusTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }
                isCrownFocused = true
            }
        }
        .onDisappear {
            crownFocusTask?.cancel()
            crownFocusTask = nil
            isCrownFocused = false
        }
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
