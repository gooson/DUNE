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
        case .muscleMap3D:
            "muscle-map-3d-\(requestID)"
        case .personalRecords:
            "personal-records-\(requestID)-\(destination.hashValue)"
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
/// Layout: readiness/recovery → workout choice → recent records/achievements → cumulative analysis.
struct ActivityView: View {
    private struct ExerciseStartConfiguration: Identifiable {
        let id = UUID()
        let exercise: ExerciseDefinition
        var templateEntry: TemplateEntry? = nil
    }

    private enum PendingQuickStartAction {
        case exercise(ExerciseDefinition)
        case template(WorkoutTemplate)
    }

    @State private var viewModel: ActivityViewModel
    @State private var showingExercisePicker = false
    @State private var showingAllRecentWorkouts = false
    @State private var showingAIWorkoutBuilder = false
    @State private var saveRecommendationAsTemplate: WorkoutTemplateRecommendation?
    @State private var exerciseStartConfiguration: ExerciseStartConfiguration?
    @State private var pendingQuickStartAction: PendingQuickStartAction?
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
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var cachedInjuryConflicts: [InjuryConflict] = []
    private let conflictUseCase = CheckInjuryConflictUseCase()
    private let scrollToTopSignal: Int
    private let notificationWorkoutID: String?
    private let notificationRouteSignal: Int
    private let shortcutTemplateID: UUID?
    private let shortcutTemplateSignal: Int
    private let notificationPersonalRecordsSignal: Int

    private enum ScrollAnchor: Hashable {
        case top
    }

    private struct RecordsUpdateKey: Equatable {
        let count: Int
        let fingerprint: Int
    }

    private var isRegular: Bool { sizeClass == .regular }

    private let refreshSignal: Int
    private let scoreRefreshService: ScoreRefreshService?

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
        scoreRefreshService: ScoreRefreshService? = nil,
        scrollToTopSignal: Int = 0,
        refreshSignal: Int = 0,
        notificationWorkoutID: String? = nil,
        notificationRouteSignal: Int = 0,
        shortcutTemplateID: UUID? = nil,
        shortcutTemplateSignal: Int = 0,
        notificationPersonalRecordsSignal: Int = 0
    ) {
        _viewModel = State(initialValue: ActivityViewModel(sharedHealthDataService: sharedHealthDataService, scoreRefreshService: scoreRefreshService))
        self.scrollToTopSignal = scrollToTopSignal
        self.refreshSignal = refreshSignal
        self.scoreRefreshService = scoreRefreshService
        self.notificationWorkoutID = notificationWorkoutID
        self.notificationRouteSignal = notificationRouteSignal
        self.shortcutTemplateID = shortcutTemplateID
        self.shortcutTemplateSignal = shortcutTemplateSignal
        self.notificationPersonalRecordsSignal = notificationPersonalRecordsSignal
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(width: 0, height: 0)
                    .id(ScrollAnchor.top)

                VStack(spacing: DS.Spacing.lg) {
                    if viewModel.isLoading && viewModel.weeklyExerciseMinutes.isEmpty {
                        // Keep the first screen and workout entry available while health data loads.
                        themeReadinessPreview
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        themeReadinessPreview

                        activityFlowContent
                    }
                }
                .padding()
                .frame(maxWidth: isRegular ? DS.Layout.rootContentMaxWidth : .infinity)
                .frame(maxWidth: .infinity)
                .coordinateSpace(name: TabHeroStartLine.coordinateSpace)
            }
            .accessibilityIdentifier("activity-root-scroll")
            .waveRefreshable {
                await viewModel.loadActivityData()
            }
            .onChange(of: scrollToTopSignal) { _, _ in
                withAnimation(DS.Animation.standard) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
        .backgroundPreferenceValue(TabHeroFramePreferenceKey.self) { heroFrame in
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
        .sheet(isPresented: $showingExercisePicker, onDismiss: runPendingQuickStartAction) {
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
        .sheet(isPresented: $showingAIWorkoutBuilder) {
            TemplateFormView()
        }
        .sheet(item: $saveRecommendationAsTemplate) { recommendation in
            NavigationStack {
                TemplateFormView(
                    prefillName: recommendation.title,
                    prefillEntries: TemplateExerciseResolver.resolveExercises(
                        from: recommendation,
                        library: library
                    )?.map { TemplateExerciseResolver.defaultEntry(for: $0) } ?? []
                )
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
        .sheet(item: $exerciseStartConfiguration) { configuration in
            ExerciseStartView(exercise: configuration.exercise, templateEntry: configuration.templateEntry)
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
            await viewModel.loadActivityData(records: recentRecords)
            recomputeInjuryConflicts()
            recomputeInjuryRisk()
            await viewModel.generateWeeklyReport()
        }
        .task(id: notificationRouteSignal) {
            await handleExternalNotificationRoute()
        }
        .task(id: shortcutTemplateSignal) {
            guard shortcutTemplateSignal > 0, let shortcutTemplateID else { return }
            let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
            guard let template = templates.first(where: { $0.id == shortcutTemplateID }),
                  !template.exerciseEntries.isEmpty else { return }
            startFromTemplate(template)
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
            await viewModel.generateWeeklyReport()
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
        .navigationDestination(isPresented: $showingAllRecentWorkouts) {
            ExerciseView()
        }
        .englishNavigationTitle("Activity")
    }

    private func sectionHeaderLink<Destination: Hashable>(
        _ destination: Destination,
        identifier: String,
        label: AnyView
    ) -> AnyView {
        AnyView(
            NavigationLink(value: destination) {
                CardNavigationHeader { label }
            }
            .buttonStyle(CardNavigationButtonStyle())
            .accessibilityIdentifier(identifier)
        )
    }

    private var themeReadinessPreview: some View {
        VStack(alignment: .leading, spacing: 18) {
            NavigationLink(value: ActivityDetailDestination.trainingReadiness) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        CardNavigationHeader(
                            showsChevron: viewModel.trainingReadiness != nil,
                            minimumHeight: 44,
                            chevronColor: readinessInk
                        ) {
                            Text(verbatim: "READINESS")
                                .font(.caption.weight(.semibold))
                                .tracking(1.5)
                                .accessibilityIdentifier("activity-hero-heading")
                                .foregroundStyle(readinessInk)
                        }
                        if viewModel.trainingReadiness?.isCalibrating == true {
                            Text("Calibrating")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.directionPreviewTextColor.opacity(0.74))
                        }
                    }

                    if let readiness = viewModel.trainingReadiness {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(readiness.score.formattedWithSeparator)
                                    .font(.largeTitle.weight(.semibold))
                                    .foregroundStyle(readinessInk)
                                    .accessibilityIdentifier("activity-hero-score-external")
                                themeReadinessCopy(readiness)
                            }
                        } else {
                            HStack(alignment: .center, spacing: 18) {
                                themeReadinessRing(readiness)
                                themeReadinessCopy(readiness)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                    } else if viewModel.isLoading {
                        ProgressView()
                            .accessibilityLabel("Loading")
                    } else {
                        Text("Need More Data")
                            .font(.headline)
                            .foregroundStyle(theme.directionPreviewTextColor.opacity(0.74))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("activity-hero-readiness")
            .accessibilityHint("View Readiness Details")
            .buttonStyle(CardNavigationButtonStyle())
            .disabled(viewModel.trainingReadiness == nil)

            if let readiness = viewModel.trainingReadiness {
                ReadinessHeroEvidenceView(
                    hrv: readiness.isCalibrating ? nil : readiness.components.hrvScore,
                    sleep: viewModel.readinessSleepAvailable ? readiness.components.sleepScore : nil,
                    recovery: viewModel.readinessRecoveryAvailable ? readiness.components.fatigueScore : nil
                )

                DisclosureGroup {
                    WeeklyHeroTrendView(
                        points: viewModel.readinessHistory,
                        title: "Recorded Readiness",
                        upperBound: 100,
                        tint: theme.accentColor,
                        accessibilityIdentifier: "activity-hero-trend"
                    )
                } label: {
                    Text("Readiness History and Evidence")
                        .font(.caption.weight(.semibold))
                }
                .tint(readinessInk)
                .accessibilityIdentifier("activity-hero-history-disclosure")

            }
        }
        .padding(20)
        .background {
            if theme == .desertWarm {
                DesertCardSurface(cornerRadius: 23)
            } else {
                RoundedRectangle(cornerRadius: 23)
                    .fill(theme.directionPreviewBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 23)
                            .strokeBorder(theme.accentColor.opacity(0.25), lineWidth: 1)
                    }
            }
        }
        .reportTabHeroFrame()
        .staggeredAppear(index: 0)
    }

    private func themeReadinessRing(_ readiness: TrainingReadiness) -> some View {
        CompactConditionRing(
            score: readiness.score,
            ringColor: theme.accentColor,
            highlightColor: theme.duskColor,
            tipColor: readiness.status.color,
            trackColor: readinessInk.opacity(0.6),
            textColor: readinessInk,
            accessibilityLabel: "Training readiness \(readiness.score), \(readiness.status.label)",
            accessibilityIdentifier: "activity-hero-ring"
        )
    }

    private var readinessInk: Color {
        theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor
    }

    private func themeReadinessCopy(_ readiness: TrainingReadiness) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(readiness.status.label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(readinessInk)
            Text(readiness.narrativeMessage)
                .font(.subheadline)
                .foregroundStyle(theme == .desertWarm ? DesertPalette.muted : readinessInk.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var activityFlowContent: some View {
        flowPair {
            VStack(spacing: DS.Spacing.lg) {
                recoveryMapSection()
                riskSection
            }
        } trailing: {
            suggestedWorkoutSection()
        }
        if !cachedInjuryConflicts.isEmpty {
            InjuryWarningBanner(conflicts: cachedInjuryConflicts)
        }
        recentWorkoutsSection
        flowPair { personalRecordsSection } trailing: { achievementSection }
        flowPair { weeklyStatsSection() } trailing: { reportSection }
        flowPair { consistencySection } trailing: { trainingVolumeSection() }
        exerciseMixSection
    }

    @ViewBuilder
    private func flowPair<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        if isRegular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                leading().frame(maxWidth: .infinity, alignment: .topLeading)
                trailing().frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            leading()
            trailing()
        }
    }

    private var riskSection: some View {
        SectionGroup(title: "Training Burden Check", icon: "shield.checkered",
                     iconColor: DS.Color.activity,
                     sectionIdentifier: "activity-section-injuryrisk",
                     headerLink: viewModel.injuryRiskAssessment == nil ? nil : {
                         sectionHeaderLink(ActivityDetailDestination.injuryRisk, identifier: "activity-injuryrisk-detail-link", label: $0)
                     }) {
            if viewModel.injuryRiskAssessment != nil {
                NavigationLink(value: ActivityDetailDestination.injuryRisk) {
                    InjuryRiskCard(
                        assessment: viewModel.injuryRiskAssessment,
                        weeklyStats: viewModel.weeklyStats,
                        streak: viewModel.workoutStreak,
                        fatigueStates: viewModel.fatigueStates,
                        sleepAvailable: !viewModel.sleepDailyData.isEmpty,
                        readinessAvailable: viewModel.trainingReadiness != nil
                    )
                }
                .buttonStyle(CardNavigationButtonStyle())
                .accessibilityIdentifier("activity-injuryrisk-detail-content")
            } else {
                InjuryRiskCard(assessment: nil)
            }
        }
    }

    private var reportSection: some View {
        SectionGroup(title: "Weekly Report", icon: "doc.text",
                     iconColor: DS.Color.activity,
                     sectionIdentifier: "activity-section-weeklyreport",
                     headerLink: viewModel.weeklyReport == nil ? nil : {
                         sectionHeaderLink(ActivityDetailDestination.weeklyReport, identifier: "activity-weeklyreport-detail-link", label: $0)
                     }) {
            if viewModel.weeklyReport != nil {
                NavigationLink(value: ActivityDetailDestination.weeklyReport) {
                    WorkoutReportCard(report: viewModel.weeklyReport)
                }
                .buttonStyle(CardNavigationButtonStyle())
                .accessibilityIdentifier("activity-weeklyreport-detail-content")
            } else {
                WorkoutReportCard(report: nil)
            }
        }
    }

    private var recentWorkoutsSection: some View {
        SectionGroup(title: "Recent Workouts", icon: "clock.arrow.circlepath", iconColor: DS.Color.activity,
                     sectionIdentifier: "activity-section-recent",
                     headerLink: { label in
            AnyView(Button { showingAllRecentWorkouts = true } label: {
                CardNavigationHeader { label }
            }
            .buttonStyle(CardNavigationButtonStyle())
            .accessibilityIdentifier("activity-recent-seeall"))
        }) {
            ExerciseListSection(
                workouts: viewModel.recentWorkouts,
                exerciseRecords: recentRecords,
                tombstonedIDs: DeletedWorkoutTombstoneStore.shared.tombstonedIDs,
                showsSeeAllButton: false,
                rewardEvents: viewModel.workoutRewardHistory
            )
        }
    }

    private var personalRecordsSection: some View {
        SectionGroup(title: "Personal Records", icon: "trophy.fill",
                     iconColor: DS.Color.activity,
                     infoAction: { showingPRInfo = true },
                     infoIdentifier: "activity-pr-info",
                     headerLink: { sectionHeaderLink(ActivityDetailDestination.personalRecords(), identifier: "activity-section-pr", label: $0) }) {
            NavigationLink(value: ActivityDetailDestination.personalRecords()) {
                PersonalRecordsSection(
                    records: viewModel.personalRecords,
                    notice: viewModel.personalRecordNotice,
                    rewardSummary: viewModel.workoutRewardSummary
                )
            }
            .buttonStyle(CardNavigationButtonStyle())
            .accessibilityIdentifier("activity-section-pr-content")
        }
    }

    private var achievementSection: some View {
        SectionGroup(title: "Achievement History", icon: "medal.fill", iconColor: DS.Color.activity,
                     headerLink: { sectionHeaderLink(ActivityDetailDestination.personalRecords(), identifier: "activity-section-achievement", label: $0) }) {
            NavigationLink(value: ActivityDetailDestination.personalRecords()) {
                AchievementHistoryPreview(events: viewModel.workoutRewardHistory)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(CardNavigationButtonStyle())
            .accessibilityIdentifier("activity-section-achievement-content")
        }
    }

    private var consistencySection: some View {
        SectionGroup(title: "Workout Consistency", icon: "flame.fill",
                     iconColor: DS.Color.activity,
                     infoAction: { showingConsistencyInfo = true },
                     infoIdentifier: "activity-consistency-info",
                     headerLink: { sectionHeaderLink(ActivityDetailDestination.consistency, identifier: "activity-section-consistency", label: $0) }) {
            NavigationLink(value: ActivityDetailDestination.consistency) {
                ConsistencyCard(streak: viewModel.workoutStreak)
            }
            .buttonStyle(CardNavigationButtonStyle())
            .accessibilityIdentifier("activity-section-consistency-content")
        }
    }

    private var exerciseMixSection: some View {
        SectionGroup(title: "Exercise Mix", icon: "chart.bar.xaxis",
                     iconColor: DS.Color.activity,
                     infoAction: { showingExerciseMixInfo = true },
                     infoIdentifier: "activity-exercise-mix-info",
                     headerLink: { sectionHeaderLink(ActivityDetailDestination.exerciseMix, identifier: "activity-section-exercisemix", label: $0) }) {
            NavigationLink(value: ActivityDetailDestination.exerciseMix) {
                ExerciseFrequencySection(summary: viewModel.exerciseMix)
            }
            .buttonStyle(CardNavigationButtonStyle())
            .accessibilityIdentifier("activity-section-exercisemix-content")
        }
    }

    // MARK: - Extracted Sections

    private func startFromTemplate(_ template: WorkoutTemplate) {
        let entries = template.exerciseEntries
        guard !entries.isEmpty else { return }

        if entries.count == 1 {
            if let definition = resolveExercise(from: entries[0]) {
                exerciseStartConfiguration = ExerciseStartConfiguration(exercise: definition, templateEntry: entries[0])
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
            exerciseStartConfiguration = ExerciseStartConfiguration(exercise: exercises[0])
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
        pendingQuickStartAction = .exercise(exercise)
        showingExercisePicker = false
    }

    private func startTemplateFromPicker(_ template: WorkoutTemplate) {
        pendingQuickStartAction = .template(template)
        showingExercisePicker = false
    }

    private func runPendingQuickStartAction() {
        guard let pendingQuickStartAction else { return }
        self.pendingQuickStartAction = nil

        switch pendingQuickStartAction {
        case .exercise(let exercise):
            exerciseStartConfiguration = ExerciseStartConfiguration(exercise: exercise)
        case .template(let template):
            startFromTemplate(template)
        }
    }

    private func recoveryMapSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "Muscle Map", icon: "figure.stand", iconColor: DS.Color.activity,
                     headerLink: { sectionHeaderLink(ActivityDetailDestination.muscleMap, identifier: "activity-musclemap-detail-link", label: $0) },
                     fillHeight: fillHeight) {
            MuscleRecoveryMapView(
                fatigueStates: viewModel.fatigueStates,
                onMuscleSelected: { muscle in selectedMuscle = muscle }
            )


        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-section-musclemap")
    }

    private func weeklyStatsSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "Weekly Training", icon: "chart.bar.fill", iconColor: DS.Color.activity,
                     headerLink: { sectionHeaderLink(ActivityDetailDestination.weeklyStats, identifier: "activity-section-weeklystats", label: $0) },
                     fillHeight: fillHeight) {
            NavigationLink(value: ActivityDetailDestination.weeklyStats) {
                WeeklyStatsGrid(stats: viewModel.weeklyStats)
            }
            .buttonStyle(CardNavigationButtonStyle())
            .accessibilityIdentifier("activity-section-weeklystats-content")
        }
    }

    private func suggestedWorkoutSection(fillHeight: Bool = false, useHistory: Bool = true) -> some View {
        SectionGroup(title: "Suggested Workout", icon: "sparkles", iconColor: DS.Color.activity, sectionIdentifier: "activity-section-suggested", fillHeight: fillHeight) {
            SuggestedWorkoutSection(
                suggestion: viewModel.workoutSuggestion,
                recommendationContext: viewModel.recommendationContext,
                availableEquipment: viewModel.recommendationAvailableEquipment,
                library: library,
                recentExerciseIDs: useHistory ? recentExerciseIDs : [],
                popularExerciseIDs: useHistory ? popularExerciseIDs : [],
                onStartExercise: { exercise in
                    exerciseStartConfiguration = ExerciseStartConfiguration(exercise: exercise)
                },
                onStartRecommendation: startRecommendation,
                onSaveRecommendationAsTemplate: { recommendation in
                    saveRecommendationAsTemplate = recommendation
                },
                onStartTemplate: startFromTemplate,
                onOpenAIWorkoutBuilder: { showingAIWorkoutBuilder = true },
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
        SectionGroup(title: "Training Load", icon: "chart.line.uptrend.xyaxis", iconColor: DS.Color.activity,
                     headerLink: { sectionHeaderLink(TrainingVolumeDestination.overview, identifier: "activity-section-volume", label: $0) },
                     fillHeight: fillHeight) {
            TrainingVolumeSummaryCard(
                trainingLoadData: viewModel.trainingLoadData,
                lastWorkoutMinutes: viewModel.lastWorkoutMinutes,
                lastWorkoutCalories: viewModel.lastWorkoutCalories,
                recentWorkoutDate: viewModel.recentWorkouts.map(\.date).max()
            )
        }
    }

    @ViewBuilder
    private func activityDetailView(for destination: ActivityDetailDestination) -> some View {
        switch destination {
        case .muscleMap:
            MuscleMapDetailView(fatigueStates: viewModel.fatigueStates)
        case .muscleMap3D:
            MuscleMap3DView(fatigueStates: viewModel.fatigueStates, highlightedMuscle: nil)
        case .personalRecords(let preselectedKind):
            PersonalRecordsDetailView(
                records: viewModel.personalRecords,
                notice: viewModel.personalRecordNotice,
                rewardSummary: viewModel.workoutRewardSummary,
                rewardHistory: viewModel.workoutRewardHistory,
                unlockedBadgeKeys: viewModel.unlockedBadgeKeys,
                preselectedKind: preselectedKind,
                recentWorkouts: viewModel.recentWorkouts
            )
        case .consistency:
            ConsistencyDetailView()
        case .exerciseMix:
            ExerciseMixDetailView(summary: viewModel.exerciseMix)
        case .trainingReadiness:
            TrainingReadinessDetailView(
                readiness: viewModel.trainingReadiness,
                scoreRefreshService: scoreRefreshService
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
            destination: .personalRecords(),
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

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegularLayout: Bool { sizeClass == .regular }
    private var previewLimit: Int { 3 }
    private var minimumCardHeight: CGFloat? { isRegularLayout ? 136 : nil }

    private var previewEvents: [WorkoutRewardEvent] {
        Array(events.prefix(previewLimit))
    }

    var body: some View {
        StandardCard {
            Group {
                if previewEvents.isEmpty {
                    emptyState
                } else {
                    populatedState
                }
            }
            .frame(maxWidth: .infinity, minHeight: minimumCardHeight, alignment: .leading)
        }
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: isRegularLayout ? DS.Spacing.sm : DS.Spacing.xs) {
            Image(systemName: "medal.fill")
                .font(isRegularLayout ? .body : .caption)
                .foregroundStyle(.tertiary)
                .frame(width: isRegularLayout ? 20 : 16, alignment: .center)

            Text(String(localized: "No achievements yet. Complete workouts to unlock milestones, badges, and levels."))
                .font(isRegularLayout ? .subheadline : .caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, isRegularLayout ? DS.Spacing.sm : 0)
    }

    private var populatedState: some View {
        VStack(alignment: .leading, spacing: isRegularLayout ? DS.Spacing.md : DS.Spacing.sm) {
            ForEach(previewEvents) { event in
                historyRow(for: event)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historyRow(for event: WorkoutRewardEvent) -> some View {
        HStack(alignment: .top, spacing: isRegularLayout ? DS.Spacing.sm : DS.Spacing.xs) {
            Image(systemName: iconName(for: event.kind))
                .font(isRegularLayout ? .caption : .caption2)
                .foregroundStyle(color(for: event.kind))
                .frame(width: isRegularLayout ? 20 : 16, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(isRegularLayout ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(eventDetailText(event))
                    .font(isRegularLayout ? .caption : .caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(event.date, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
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
