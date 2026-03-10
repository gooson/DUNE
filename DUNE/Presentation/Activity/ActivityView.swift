import SwiftUI
import SwiftData

enum ActivityRecordChangeFingerprint {
    static func make(from records: [ExerciseRecord]) -> Int {
        var hasher = Hasher()

        for record in records {
            hasher.combine(record.id)
            hasher.combine(record.date)
            hasher.combine(record.exerciseType)
            hasher.combine(record.duration)
            hasher.combine(record.calories)
            hasher.combine(record.distance)
            hasher.combine(record.stepCount)
            hasher.combine(record.averagePaceSecondsPerKm)
            hasher.combine(record.averageCadenceStepsPerMinute)
            hasher.combine(record.elevationGainMeters)
            hasher.combine(record.floorsAscended)
            hasher.combine(record.cardioMachineLevelAverage)
            hasher.combine(record.cardioMachineLevelMax)
            hasher.combine(record.isFromHealthKit)
            hasher.combine(record.healthKitWorkoutID)
            hasher.combine(record.exerciseDefinitionID)
            hasher.combine(record.primaryMusclesRaw)
            hasher.combine(record.secondaryMusclesRaw)
            hasher.combine(record.equipmentRaw)
            hasher.combine(record.estimatedCalories)
            hasher.combine(record.calorieSourceRaw)
            hasher.combine(record.rpe)
            hasher.combine(record.autoIntensityRaw)
            hasher.combine(record.cardioFitnessVO2Max)
            hasher.combine(record.createdAt)

            for set in record.completedSets {
                hasher.combine(set.id)
                hasher.combine(set.setNumber)
                hasher.combine(set.setTypeRaw)
                hasher.combine(set.weight)
                hasher.combine(set.reps)
                hasher.combine(set.duration)
                hasher.combine(set.distance)
                hasher.combine(set.intensity)
                hasher.combine(set.isCompleted)
                hasher.combine(set.restDuration)
            }
        }

        return hasher.finalize()
    }
}

struct NotificationActivityDestination: Identifiable, Hashable {
    let destination: ActivityDetailDestination
    let requestID: Int

    var id: String {
        switch destination {
        case .muscleMap:
            "muscle-map-\(requestID)"
        case .personalRecords:
            "personal-records-\(requestID)"
        case .consistency:
            "consistency-\(requestID)"
        case .exerciseMix:
            "exercise-mix-\(requestID)"
        case .trainingReadiness:
            "training-readiness-\(requestID)"
        case .weeklyStats:
            "weekly-stats-\(requestID)"
        case .injuryRisk:
            "injury-risk-\(requestID)"
        case .weeklyReport:
            "weekly-report-\(requestID)"
        }
    }
}

/// Activity tab — Hero-first layout.
/// Layout: Hero → Muscle Map → Weekly Stats → Search+Suggestion+Templates → Volume → Workouts → PRs → Consistency → Frequency.
struct ActivityView: View {
    @State private var viewModel: ActivityViewModel
    @State private var showingExercisePicker = false
    @State private var selectedExercise: ExerciseDefinition?
    @State private var templateConfig: TemplateWorkoutConfig?
    @State private var selectedMuscle: MuscleGroup?
    @State private var showingPRInfo = false
    @State private var showingConsistencyInfo = false
    @State private var showingExerciseMixInfo = false
    @State private var notificationWorkoutDestinationID: String?
    @State private var notificationWorkoutLookup: [String: WorkoutSummary] = [:]
    @State private var notificationActivityDestination: NotificationActivityDestination?
    @State private var missingNotificationWorkoutID: String?
    @State private var syncToastMessage: String?
    @State private var syncToastDismissTask: Task<Void, Never>?
    @Environment(\.modelContext) private var modelContext

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    @Query(sort: \ExerciseRecord.date, order: .reverse) private var recentRecords: [ExerciseRecord]
    @Query(sort: \ExerciseDefaultRecord.lastUsedDate, order: .reverse) private var exerciseDefaults: [ExerciseDefaultRecord]
    @Query(filter: #Predicate<InjuryRecord> { $0.endDate == nil },
           sort: \InjuryRecord.startDate, order: .reverse) private var activeInjuryRecords: [InjuryRecord]

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var cachedInjuryConflicts: [InjuryConflict] = []
    private let conflictUseCase = CheckInjuryConflictUseCase()
    private let scrollToTopSignal: Int
    private let notificationWorkoutID: String?
    private let notificationRouteSignal: Int
    private let notificationPersonalRecordsSignal: Int
    @State private var heroFrame: CGRect?

    private enum ScrollAnchor: Hashable {
        case top
    }

    private struct RecordsUpdateKey: Equatable {
        let count: Int
        let fingerprint: Int
    }

    private var isRegular: Bool { sizeClass == .regular }

    private let refreshSignal: Int

    private var recordsUpdateKey: RecordsUpdateKey {
        RecordsUpdateKey(
            count: recentRecords.count,
            fingerprint: recentRecordsFingerprint
        )
    }

    private var recentRecordsFingerprint: Int {
        ActivityRecordChangeFingerprint.make(from: recentRecords)
    }

    private var activeInjurySnapshot: [InjuryInfo] {
        activeInjuryRecords.map { $0.toInjuryInfo() }
    }

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        scrollToTopSignal: Int = 0,
        refreshSignal: Int = 0,
        notificationWorkoutID: String? = nil,
        notificationRouteSignal: Int = 0,
        notificationPersonalRecordsSignal: Int = 0
    ) {
        _viewModel = State(initialValue: ActivityViewModel(sharedHealthDataService: sharedHealthDataService))
        self.scrollToTopSignal = scrollToTopSignal
        self.refreshSignal = refreshSignal
        self.notificationWorkoutID = notificationWorkoutID
        self.notificationRouteSignal = notificationRouteSignal
        self.notificationPersonalRecordsSignal = notificationPersonalRecordsSignal
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(ScrollAnchor.top)

                VStack(spacing: DS.Spacing.lg) {
                    if viewModel.isLoading && viewModel.weeklyExerciseMinutes.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // ① Training Readiness Hero Card
                        NavigationLink(value: ActivityDetailDestination.trainingReadiness) {
                            TrainingReadinessHeroCard(
                                readiness: viewModel.trainingReadiness,
                                isCalibrating: viewModel.trainingReadiness?.isCalibrating ?? true
                            )
                        }
                        .reportTabHeroFrame()
                        .accessibilityIdentifier("activity-hero-readiness")
                        .buttonStyle(.plain)

                        // ② Recovery Map + Weekly Stats (side-by-side on iPad)
                        if isRegular {
                            HStack(alignment: .top, spacing: DS.Spacing.md) {
                                recoveryMapSection(fillHeight: true)
                                weeklyStatsSection(fillHeight: true)
                            }
                        } else {
                            recoveryMapSection()
                            weeklyStatsSection()
                        }

                        // ③ Injury Warning Banner
                        if !cachedInjuryConflicts.isEmpty {
                            InjuryWarningBanner(conflicts: cachedInjuryConflicts)
                        }

                        // ③.5 Injury Risk Assessment
                        SectionGroup(title: "Injury Risk", icon: "shield.checkered", iconColor: DS.Color.activity) {
                            if viewModel.injuryRiskAssessment != nil {
                                NavigationLink(value: ActivityDetailDestination.injuryRisk) {
                                    InjuryRiskCard(assessment: viewModel.injuryRiskAssessment)
                                }
                                .buttonStyle(.plain)
                            } else {
                                InjuryRiskCard(assessment: nil)
                            }
                        }
                        .accessibilityIdentifier("activity-section-injuryrisk")

                        // ④ Suggested Workout (with search + templates)
                        suggestedWorkoutSection()

                        // ⑤ Training Volume
                        trainingVolumeSection()

                        // ⑥ Weekly Report
                        SectionGroup(title: "Weekly Report", icon: "doc.text", iconColor: DS.Color.activity) {
                            if viewModel.weeklyReport != nil {
                                NavigationLink(value: ActivityDetailDestination.weeklyReport) {
                                    WorkoutReportCard(report: viewModel.weeklyReport)
                                }
                                .buttonStyle(.plain)
                            } else {
                                WorkoutReportCard(report: nil)
                            }
                        }
                        .accessibilityIdentifier("activity-section-weeklyreport")

                        // ⑧ Recent Workouts
                        SectionGroup(title: "Recent Workouts", icon: "clock.arrow.circlepath", iconColor: DS.Color.activity) {
                            ExerciseListSection(
                                workouts: viewModel.recentWorkouts,
                                exerciseRecords: recentRecords
                            )
                        }

                        // ⑨ Personal Records
                        SectionGroup(title: "Personal Records", icon: "trophy.fill",
                                     iconColor: DS.Color.activity,
                                     infoAction: { showingPRInfo = true }) {
                            NavigationLink(value: ActivityDetailDestination.personalRecords) {
                                PersonalRecordsSection(
                                    records: viewModel.personalRecords,
                                    notice: viewModel.personalRecordNotice,
                                    rewardSummary: viewModel.workoutRewardSummary
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("activity-section-pr")
                        }

                        SectionGroup(title: "Achievement History", icon: "medal.fill", iconColor: DS.Color.activity) {
                            NavigationLink(value: ActivityDetailDestination.personalRecords) {
                                AchievementHistoryPreview(events: viewModel.workoutRewardHistory)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("activity-section-achievement")
                        }

                        // ⑩ Consistency
                        SectionGroup(title: "Consistency", icon: "flame.fill",
                                     iconColor: DS.Color.activity,
                                     infoAction: { showingConsistencyInfo = true }) {
                            NavigationLink(value: ActivityDetailDestination.consistency) {
                                ConsistencyCard(streak: viewModel.workoutStreak)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("activity-section-consistency")
                        }

                        // ⑪ Exercise Mix
                        SectionGroup(title: "Exercise Mix", icon: "chart.bar.xaxis",
                                     iconColor: DS.Color.activity,
                                     infoAction: { showingExerciseMixInfo = true }) {
                            NavigationLink(value: ActivityDetailDestination.exerciseMix) {
                                ExerciseFrequencySection(frequencies: viewModel.exerciseFrequencies)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("activity-section-exercisemix")
                        }
                    }
                }
                .padding()
                .coordinateSpace(name: TabHeroStartLine.coordinateSpace)
            }
            .waveRefreshable {
                await viewModel.loadActivityData()
            }
            .onChange(of: scrollToTopSignal) { _, _ in
                withAnimation(DS.Animation.standard) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
        .onPreferenceChange(TabHeroFramePreferenceKey.self) { heroFrame = $0 }
        .background {
            TabWaveBackground()
                .environment(\.tabHeroStartLineInset, heroFrame.map(TabHeroStartLine.inset(for:)))
        }
        .overlay(alignment: .top) {
            if let syncToastMessage {
                ActivitySyncToast(message: syncToastMessage) {
                    Task { await viewModel.loadActivityData() }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                    )
                )
                .animation(DS.Animation.snappy, value: syncToastMessage)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("activity-toolbar-add")
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(
                library: library,
                recentExerciseIDs: recentExerciseIDs,
                preferredExerciseIDs: preferredExerciseIDs,
                popularExerciseIDs: popularExerciseIDs,
                mode: .quickStart,
                onStartTemplate: startTemplateFromPicker
            ) { exercise in
                startExerciseFromPicker(exercise)
            }
        }
        .sheet(item: $selectedMuscle) { muscle in
            MuscleDetailPopover(
                muscle: muscle,
                fatigueState: viewModel.fatigueStates.first { $0.muscle == muscle },
                library: library
            )
        }
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .navigationDestination(for: TrainingVolumeDestination.self) { destination in
            switch destination {
            case .overview:
                TrainingVolumeDetailView()
            case .exerciseType(let typeKey, let displayName, let categoryRawValue, let equipmentRawValue):
                ExerciseTypeDetailView(
                    typeKey: typeKey,
                    displayName: displayName,
                    categoryRawValue: categoryRawValue,
                    equipmentRawValue: equipmentRawValue
                )
            }
        }
        .navigationDestination(for: ActivityDetailDestination.self) { destination in
            activityDetailView(for: destination)
        }
        .navigationDestination(item: $notificationActivityDestination) { destination in
            activityDetailView(for: destination.destination)
        }
        .navigationDestination(item: $notificationWorkoutDestinationID) { workoutID in
            if let workout = notificationWorkoutLookup[workoutID] {
                HealthKitWorkoutDetailView(workout: workout)
            } else {
                NotificationTargetNotFoundView(workoutID: workoutID)
            }
        }
        .navigationDestination(item: $missingNotificationWorkoutID) { workoutID in
            NotificationTargetNotFoundView(workoutID: workoutID)
        }
        .sheet(isPresented: $showingPRInfo) {
            PersonalRecordsInfoSheet()
        }
        .sheet(isPresented: $showingConsistencyInfo) {
            ConsistencyInfoSheet()
        }
        .sheet(isPresented: $showingExerciseMixInfo) {
            ExerciseMixInfoSheet()
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseStartView(exercise: exercise)
                .interactiveDismissDisabled()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(item: $templateConfig) { config in
            TemplateWorkoutContainerView(config: config)
        }
        // Keep heavy HealthKit reload tied to coordinator/manual refresh only.
        // SwiftData sync churn should update derived UI state without cancel/restart storms.
        .task(id: refreshSignal) {
            await viewModel.loadActivityData()
            recomputeInjuryConflicts()
            recomputeInjuryRisk()
            viewModel.generateWeeklyReport()
        }
        .task(id: notificationRouteSignal) {
            await handleExternalNotificationRoute()
        }
        .task(id: notificationPersonalRecordsSignal) {
            await handleExternalPersonalRecordsRoute()
        }
        // Coalesce frequent SwiftData sync updates into a cancellable/debounced derived-state refresh.
        .task(id: recordsUpdateKey) {
            WorkoutTypeCorrectionStore.shared.backfillTitles(from: recentRecords)
            await viewModel.refreshSuggestionFromRecords(recentRecords)
            recomputeInjuryConflicts()
            recomputeInjuryRisk()
            viewModel.generateWeeklyReport()
        }
        .onChange(of: activeInjurySnapshot) { _, _ in
            recomputeInjuryConflicts()
            recomputeInjuryRisk()
        }
        .onChange(of: viewModel.errorMessage) { _, newMessage in
            guard let newMessage, !newMessage.isEmpty else {
                dismissSyncToast()
                return
            }
            presentSyncToast(message: newMessage)
        }
        .onDisappear {
            syncToastDismissTask?.cancel()
            syncToastDismissTask = nil
        }
        .englishNavigationTitle("Activity")
    }

    // MARK: - Extracted Sections

    private func startFromTemplate(_ template: WorkoutTemplate) {
        let entries = template.exerciseEntries
        guard !entries.isEmpty else { return }

        if entries.count == 1 {
            if let definition = resolveExercise(from: entries[0]) {
                selectedExercise = definition
            }
            return
        }

        let exercises = entries.compactMap { resolveExercise(from: $0) }
        guard !exercises.isEmpty else { return }

        templateConfig = TemplateWorkoutConfig(
            templateName: template.name,
            exercises: exercises,
            templateEntries: entries
        )
    }

    private func startRecommendation(_ recommendation: WorkoutTemplateRecommendation) {
        guard let exercises = TemplateExerciseResolver.resolveExercises(
            from: recommendation,
            library: library
        ) else {
            AppLogger.exercise.warning("[Recommendation] Failed to resolve sequence for \(recommendation.id)")
            return
        }
        guard !exercises.isEmpty else { return }

        if exercises.count == 1 {
            selectedExercise = exercises[0]
            return
        }

        templateConfig = TemplateWorkoutConfig(
            templateName: recommendation.title,
            exercises: exercises,
            templateEntries: exercises.map { TemplateExerciseResolver.defaultEntry(for: $0) }
        )
    }

    private func resolveExercise(from entry: TemplateEntry) -> ExerciseDefinition? {
        if let definition = library.exercise(byID: entry.exerciseDefinitionID) {
            return definition
        } else if entry.exerciseDefinitionID.hasPrefix("custom-") {
            return ExerciseDefinition(
                id: entry.exerciseDefinitionID,
                name: entry.exerciseName,
                localizedName: entry.exerciseName,
                category: .strength,
                inputType: .setsRepsWeight,
                primaryMuscles: [],
                secondaryMuscles: [],
                equipment: Equipment(rawValue: entry.equipment ?? "") ?? .bodyweight,
                metValue: 5.0
            )
        }
        return nil
    }

    private func startExerciseFromPicker(_ exercise: ExerciseDefinition) {
        showingExercisePicker = false
        scheduleQuickStartAction {
            selectedExercise = exercise
        }
    }

    private func startTemplateFromPicker(_ template: WorkoutTemplate) {
        showingExercisePicker = false
        scheduleQuickStartAction {
            startFromTemplate(template)
        }
    }

    private func scheduleQuickStartAction(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            while showingExercisePicker {
                await Task.yield()
            }
            await Task.yield()
            action()
        }
    }

    private func recoveryMapSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "Muscle Map", icon: "figure.stand", iconColor: DS.Color.activity, fillHeight: fillHeight) {
            MuscleRecoveryMapView(
                fatigueStates: viewModel.fatigueStates,
                onMuscleSelected: { muscle in selectedMuscle = muscle }
            )

            NavigationLink(value: ActivityDetailDestination.muscleMap) {
                HStack {
                    Text("View Details")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DS.Color.activity)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.Color.activity.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DS.Spacing.xs)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("activity-musclemap-detail-link")
        }
        .accessibilityIdentifier("activity-section-musclemap")
    }

    private func weeklyStatsSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "This Week", icon: "chart.bar.fill", iconColor: DS.Color.activity, fillHeight: fillHeight) {
            NavigationLink(value: ActivityDetailDestination.weeklyStats) {
                WeeklyStatsGrid(stats: viewModel.weeklyStats)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("activity-section-weeklystats")
        }
    }

    private func suggestedWorkoutSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "Suggested Workout", icon: "sparkles", iconColor: DS.Color.activity, fillHeight: fillHeight) {
            SuggestedWorkoutSection(
                suggestion: viewModel.workoutSuggestion,
                recommendationContext: viewModel.recommendationContext,
                availableEquipment: viewModel.recommendationAvailableEquipment,
                library: library,
                recentExerciseIDs: recentExerciseIDs,
                popularExerciseIDs: popularExerciseIDs,
                onStartExercise: { exercise in selectedExercise = exercise },
                onStartRecommendation: startRecommendation,
                onStartTemplate: startFromTemplate,
                onContextChanged: { context in
                    viewModel.setRecommendationContext(context)
                },
                isEquipmentAvailable: { equipment in
                    viewModel.isEquipmentAvailable(equipment)
                },
                onSetEquipmentAvailability: { equipment, isAvailable in
                    viewModel.setEquipmentAvailability(equipment, isAvailable: isAvailable)
                },
                isExerciseExcluded: { exerciseID in
                    viewModel.isExerciseExcludedFromRecommendation(exerciseID)
                },
                onSetExerciseExcluded: { excluded, exerciseID in
                    viewModel.setExerciseExcludedFromRecommendation(excluded, exerciseID: exerciseID)
                },
                templateRecommendations: viewModel.templateRecommendations,
                onBrowseAll: { showingExercisePicker = true }
            )
        }
    }

    private func trainingVolumeSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "Training Volume", icon: "chart.line.uptrend.xyaxis", iconColor: DS.Color.activity, fillHeight: fillHeight) {
            TrainingVolumeSummaryCard(
                trainingLoadData: viewModel.trainingLoadData,
                lastWorkoutMinutes: viewModel.lastWorkoutMinutes,
                lastWorkoutCalories: viewModel.lastWorkoutCalories
            )
        }
    }

    @ViewBuilder
    private func activityDetailView(for destination: ActivityDetailDestination) -> some View {
        switch destination {
        case .muscleMap:
            MuscleMapDetailView(fatigueStates: viewModel.fatigueStates)
        case .personalRecords:
            PersonalRecordsDetailView(
                records: viewModel.personalRecords,
                notice: viewModel.personalRecordNotice,
                rewardSummary: viewModel.workoutRewardSummary,
                rewardHistory: viewModel.workoutRewardHistory
            )
        case .consistency:
            ConsistencyDetailView()
        case .exerciseMix:
            ExerciseMixDetailView()
        case .trainingReadiness:
            TrainingReadinessDetailView(
                readiness: viewModel.trainingReadiness,
                hrvDailyAverages: viewModel.hrvDailyAverages,
                rhrDailyData: viewModel.rhrDailyData,
                sleepDailyData: viewModel.sleepDailyData
            )
        case .weeklyStats:
            WeeklyStatsDetailView()
        case .injuryRisk:
            InjuryRiskDetailView(assessment: viewModel.injuryRiskAssessment)
        case .weeklyReport:
            WorkoutReportDetailView(report: viewModel.weeklyReport)
        }
    }

    // MARK: - Helpers

    private func recomputeInjuryRisk() {
        let infos = activeInjuryRecords.filter(\.isActive).map { $0.toInjuryInfo() }
        viewModel.recomputeInjuryRisk(activeInjuries: infos)
    }

    private func recomputeInjuryConflicts() {
        guard !activeInjuryRecords.isEmpty else {
            cachedInjuryConflicts = []
            return
        }
        let suggestedMuscles = viewModel.workoutSuggestion?.focusMuscles ?? []
        guard !suggestedMuscles.isEmpty else {
            cachedInjuryConflicts = []
            return
        }
        let infos = activeInjuryRecords.filter(\.isActive).map { $0.toInjuryInfo() }
        let result = conflictUseCase.execute(input: .init(
            exerciseMuscles: suggestedMuscles,
            activeInjuries: infos
        ))
        cachedInjuryConflicts = result.conflicts
    }

    private func presentSyncToast(message: String) {
        syncToastDismissTask?.cancel()

        withAnimation(DS.Animation.standard) {
            syncToastMessage = message
        }

        syncToastDismissTask = Task {
            do {
                try await Task.sleep(nanoseconds: 3_500_000_000)
            } catch is CancellationError {
                return
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(DS.Animation.standard) {
                    syncToastMessage = nil
                }
            }
        }
    }

    private func dismissSyncToast() {
        syncToastDismissTask?.cancel()
        syncToastDismissTask = nil

        if syncToastMessage != nil {
            withAnimation(DS.Animation.standard) {
                syncToastMessage = nil
            }
        }
    }

    private func handleExternalNotificationRoute() async {
        guard notificationRouteSignal > 0,
              let targetWorkoutID = notificationWorkoutID,
              !targetWorkoutID.isEmpty else {
            return
        }

        if let current = viewModel.recentWorkouts.first(where: { $0.id == targetWorkoutID }) {
            notificationWorkoutLookup[targetWorkoutID] = current
            notificationWorkoutDestinationID = targetWorkoutID
            return
        }

#if DEBUG
        let scenario = UITestSeedScenario.current()
        if let mocked = TestDataSeeder.mockWorkoutSummary(for: scenario, workoutID: targetWorkoutID) {
            notificationWorkoutLookup[targetWorkoutID] = mocked
            notificationWorkoutDestinationID = targetWorkoutID
            return
        }
#endif

        // Retry once after forcing a refresh to absorb timing gaps on cold launch.
        await viewModel.loadActivityData()

        if let refreshed = viewModel.recentWorkouts.first(where: { $0.id == targetWorkoutID }) {
            notificationWorkoutLookup[targetWorkoutID] = refreshed
            notificationWorkoutDestinationID = targetWorkoutID
            return
        }

#if DEBUG
        if let mocked = TestDataSeeder.mockWorkoutSummary(
            for: UITestSeedScenario.current(),
            workoutID: targetWorkoutID
        ) {
            notificationWorkoutLookup[targetWorkoutID] = mocked
            notificationWorkoutDestinationID = targetWorkoutID
            return
        }
#endif

        missingNotificationWorkoutID = targetWorkoutID
    }

    private func handleExternalPersonalRecordsRoute() async {
        guard notificationPersonalRecordsSignal > 0 else { return }

        notificationActivityDestination = NotificationActivityDestination(
            destination: .personalRecords,
            requestID: notificationPersonalRecordsSignal
        )
    }

    private var recentExerciseIDs: [String] {
        var seen = Set<String>()
        return recentRecords.compactMap { record in
            guard let id = record.exerciseDefinitionID, !seen.contains(id) else { return nil }
            seen.insert(id)
            return id
        }
    }

    private var popularExerciseIDs: [String] {
        let limit = 10
        let usages: [QuickStartPopularityService.Usage] = recentRecords.compactMap { record in
            guard let id = record.exerciseDefinitionID else { return nil }
            return .init(exerciseDefinitionID: id, date: record.date)
        }
        let ranked = QuickStartPopularityService.popularExerciseIDs(
            from: usages,
            limit: limit,
            canonicalize: QuickStartCanonicalService.canonicalExerciseID(for:)
        )
        if ranked.count >= limit { return ranked }

        // Fill remaining slots from library when usage history is insufficient
        let existing = Set(ranked)
        let fallback = library.allExercises()
            .lazy
            .map(\.id)
            .filter { !existing.contains($0) }
            .prefix(limit - ranked.count)
        return ranked + fallback
    }

    private var preferredExerciseIDs: [String] {
        var seen = Set<String>()
        return exerciseDefaults.compactMap { record in
            guard record.isPreferred else { return nil }
            let representativeID = library.representativeExercise(byID: record.exerciseDefinitionID)?.id
                ?? record.exerciseDefinitionID
            guard !representativeID.isEmpty else { return nil }
            let canonicalID = QuickStartCanonicalService.canonicalExerciseID(for: representativeID)
            guard seen.insert(canonicalID).inserted else { return nil }
            return representativeID
        }
    }
}

private struct AchievementHistoryPreview: View {
    let events: [WorkoutRewardEvent]

    private var previewEvents: [WorkoutRewardEvent] {
        Array(events.prefix(3))
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if previewEvents.isEmpty {
                    Text(String(localized: "No achievements yet. Complete workouts to unlock milestones, badges, and levels."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(previewEvents) { event in
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: iconName(for: event.kind))
                                .font(.caption2)
                                .foregroundStyle(color(for: event.kind))
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .lineLimit(1)
                                Text(eventDetailText(event))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Text(event.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func iconName(for kind: WorkoutRewardEventKind) -> String {
        switch kind {
        case .milestone: "flag.checkered.circle.fill"
        case .personalRecord: "trophy.fill"
        case .badgeUnlocked: "medal.fill"
        case .levelUp: "star.circle.fill"
        }
    }

    private func color(for kind: WorkoutRewardEventKind) -> Color {
        switch kind {
        case .milestone: DS.Color.activity
        case .personalRecord: .orange
        case .badgeUnlocked: .yellow
        case .levelUp: .mint
        }
    }

    private func eventDetailText(_ event: WorkoutRewardEvent) -> String {
        guard let activityType = WorkoutActivityType(rawValue: event.activityTypeRawValue) else {
            return event.detail
        }
        if event.kind == .levelUp {
            return event.detail
        }
        return String.localizedStringWithFormat(
            String(localized: "%1$@: %2$@"),
            activityType.displayName,
            event.detail
        )
    }
}

private struct ActivitySyncToast: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        InlineCard {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Color.caution)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(2)

                Spacer(minLength: DS.Spacing.xs)

                Button("Retry") {
                    onRetry()
                }
                .font(.caption.weight(.semibold))
            }
        }
        .accessibilityIdentifier("activity-sync-toast")
    }
}

#Preview {
    ActivityView()
        .modelContainer(for: [ExerciseRecord.self, WorkoutSet.self, InjuryRecord.self], inMemory: true)
}
