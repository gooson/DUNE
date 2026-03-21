import SwiftUI
import SwiftData

enum LifeHabitLogSync {
    static func insert(_ log: HabitLog, into habit: HabitDefinition) {
        if habit.logs == nil {
            habit.logs = []
        }
        log.habitDefinition = habit
        if habit.logs?.contains(where: { $0.id == log.id }) != true {
            habit.logs?.append(log)
        }
    }

    static func delete(_ logs: [HabitLog], from habit: HabitDefinition) {
        guard !logs.isEmpty else { return }

        let ids = Set(logs.map(\.id))
        habit.logs?.removeAll { ids.contains($0.id) }
    }
}

struct LifeView: View {
    @State private var viewModel = LifeViewModel()
    @State private var localRefreshSignal = 0
    @State private var isShowingTemplateSheet = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme

    private let scrollToTopSignal: Int
    private let refreshSignal: Int
    @State private var heroFrame: CGRect?

    private var isRegular: Bool { sizeClass == .regular }

    private enum ScrollAnchor: Hashable {
        case top
    }

    init(scrollToTopSignal: Int = 0, refreshSignal: Int = 0) {
        self.scrollToTopSignal = scrollToTopSignal
        self.refreshSignal = refreshSignal
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(ScrollAnchor.top)

                VStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                    // Isolated @Query child — prevents parent re-layout (Correction #179)
                    HabitListQueryView(
                        viewModel: viewModel,
                        refreshSignal: refreshSignal + localRefreshSignal
                    )
                }
                .padding(isRegular ? DS.Spacing.xxl : DS.Spacing.lg)
                .coordinateSpace(name: TabHeroStartLine.coordinateSpace)
            }
            .scrollBounceBehavior(.basedOnSize)
            .waveRefreshable {
                await MainActor.run {
                    localRefreshSignal += 1
                }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.resetForm()
                        viewModel.isShowingAddSheet = true
                    } label: {
                        Label("New Habit", systemImage: "plus")
                    }

                    Button {
                        isShowingTemplateSheet = true
                    } label: {
                        Label("From Template", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add habit")
                .accessibilityIdentifier("life-toolbar-add")
            }
        }
        .sheet(isPresented: $isShowingTemplateSheet) {
            HabitTemplateSheet(
                viewModel: viewModel,
                onSelect: {
                    viewModel.isShowingAddSheet = true
                }
            )
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            HabitFormSheet(
                viewModel: viewModel,
                isEdit: false,
                onSave: {
                    if let habit = viewModel.createValidatedHabit() {
                        modelContext.insert(habit)
                        viewModel.refreshReminderSchedule(for: habit)
                        viewModel.didFinishSaving()
                        viewModel.resetForm()
                        viewModel.isShowingAddSheet = false
                    }
                }
            )
        }
        .sheet(isPresented: $viewModel.isShowingEditSheet) {
            if viewModel.editingHabit != nil {
                HabitFormSheet(
                    viewModel: viewModel,
                    isEdit: true,
                    onSave: {
                        if let habit = viewModel.editingHabit, viewModel.applyUpdate(to: habit) {
                            viewModel.refreshReminderSchedule(for: habit)
                            viewModel.didFinishSaving()
                            viewModel.isShowingEditSheet = false
                            viewModel.resetForm()
                        }
                    }
                )
            }
        }
        .englishNavigationTitle("Life")
    }
}

// MARK: - Isolated @Query Child View
// Extracted to prevent SwiftData @Query observation from triggering parent ScrollView re-layout (Correction #179).

private struct HabitListQueryView: View {
    @Query(
        filter: #Predicate<HabitDefinition> { !$0.isArchived },
        sort: \HabitDefinition.sortOrder
    ) private var habits: [HabitDefinition]
    @Query(sort: \HabitLog.date, order: .reverse) private var habitLogs: [HabitLog]
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]

    @Bindable var viewModel: LifeViewModel
    let refreshSignal: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Correction #68: O(1) lookup instead of O(N) per row
    @State private var habitsByID: [UUID: HabitDefinition] = [:]
    // Correction #102: cached today exercise check (avoid body-path Calendar ops)
    @State private var cachedTodayExerciseExists = false
    @State private var historySelection: HabitHistorySelection?
    @State private var actionSelection: HabitActionSelection?
    @State private var heroAppeared = false
    @State private var selectedCategoryFilter: HabitIconCategory?
    @State private var weeklyRates: [WeeklyCompletionRate] = []
    @State private var monthlyRates: [MonthlyCompletionRate] = []
    @State private var heatmapData: [DailyCompletionCount] = []
    @State private var weeklyReport: WeeklyHabitReport?
    @State private var showingReport = false
    @State private var showingHeatmapDetail = false

    private struct HabitHistorySelection: Identifiable {
        let id: UUID
    }

    private struct HabitActionSelection: Identifiable {
        let id: UUID
    }

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Hero: completion rate
            heroSection
                .reportTabHeroFrame()
                .accessibilityIdentifier("life-hero-progress")

            // Analytics section (chart + heatmap)
            if !habits.isEmpty {
                analyticsSection
            }

            if isRegular {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    habitsSection(fillHeight: true)
                    autoAchievementsSection(fillHeight: true)
                }
            } else {
                habitsSection()
                autoAchievementsSection()
            }
        }
        .background {
            // Isolated @Query child — keeps today's exercise lookup off the main body path.
            TodayExerciseCheckView(exists: $cachedTodayExerciseExists)
        }
        .onChange(of: habitDefinitionSignature) { _, _ in
            recalculate()
        }
        .onChange(of: habitLogSignature) { _, _ in
            recalculate()
        }
        .onChange(of: autoAchievementInputSignature) { _, _ in
            recalculate()
        }
        .onChange(of: refreshSignal) { _, _ in
            recalculate()
        }
        .onChange(of: viewModel.isShowingEditSheet) { old, new in
            // Recalculate when edit sheet dismisses (habit properties may have changed)
            if old, !new { recalculate() }
        }
        .onChange(of: cachedTodayExerciseExists) { _, _ in
            recalculate()
        }
        .onAppear {
            recalculate()
        }
        .sheet(item: $historySelection) { selection in
            if let habit = habitsByID[selection.id] {
                HabitHistorySheet(
                    habitName: habit.name,
                    iconCategory: habit.iconCategory,
                    habitType: habit.habitType,
                    entries: viewModel.historyEntries(for: habit)
                )
            }
        }
    }

    private var autoAchievementInputSignature: Int {
        var hasher = Hasher()
        hasher.combine(exerciseRecords.count)
        for record in exerciseRecords.prefix(200) {
            hasher.combine(record.id)
            hasher.combine(record.healthKitWorkoutID ?? "")
            hasher.combine(record.isFromHealthKit)
            hasher.combine(record.exerciseDefinitionID ?? "")
            hasher.combine(record.exerciseType)
            hasher.combine(record.distance ?? -1)
            hasher.combine(record.hasSetData)
        }
        return hasher.finalize()
    }

    private var habitDefinitionSignature: Int {
        var hasher = Hasher()
        hasher.combine(habits.count)
        for habit in habits {
            hasher.combine(habit.id)
            hasher.combine(habit.name)
            hasher.combine(habit.iconCategoryRaw)
            hasher.combine(habit.habitTypeRaw)
            hasher.combine(habit.goalValue)
            hasher.combine(habit.goalUnit ?? "")
            hasher.combine(habit.frequencyTypeRaw)
            hasher.combine(habit.weeklyTargetDays)
            hasher.combine(habit.recurringStartPointRaw)
            hasher.combine(habit.recurringCustomStartDate)
            hasher.combine(habit.recurringStartConfiguredAt)
            hasher.combine(habit.isAutoLinked)
            hasher.combine(habit.autoLinkSourceRaw ?? "")
            hasher.combine(habit.sortOrder)
            hasher.combine(habit.isArchived)
            hasher.combine(habit.reminderHour)
            hasher.combine(habit.reminderMinute)
            hasher.combine(habit.timeOfDayRaw)
        }
        return hasher.finalize()
    }

    private var habitLogSignature: Int {
        var hasher = Hasher()
        hasher.combine(habitLogs.count)
        for log in habitLogs {
            hasher.combine(log.id)
            hasher.combine(log.habitDefinition?.id)
            hasher.combine(log.date)
            hasher.combine(log.value)
            hasher.combine(log.memo ?? "")
        }
        return hasher.finalize()
    }

    // MARK: - Analytics Section

    private var analyticsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            HabitCompletionChartView(
                weeklyRates: weeklyRates,
                monthlyRates: monthlyRates
            )

            HabitHeatmapView(data: heatmapData) {
                showingHeatmapDetail = true
            }

            if weeklyReport != nil {
                Button {
                    showingReport = true
                } label: {
                    Label("View Weekly Report", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.bold())
                        .foregroundStyle(DS.Color.tabLife)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .fill(.ultraThinMaterial)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("life-weekly-report-button")
            }
        }
        .navigationDestination(isPresented: $showingReport) {
            if let report = weeklyReport {
                WeeklyHabitReportView(report: report)
            }
        }
        .navigationDestination(isPresented: $showingHeatmapDetail) {
            HabitHeatmapDetailView(data: heatmapData)
        }
    }

    // MARK: - Category Filter

    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                filterChip(label: String(localized: "All"), isSelected: selectedCategoryFilter == nil) {
                    selectedCategoryFilter = nil
                }

                ForEach(activeCategories, id: \.self) { category in
                    filterChip(
                        label: category.displayName,
                        icon: category.iconName,
                        isSelected: selectedCategoryFilter == category
                    ) {
                        selectedCategoryFilter = selectedCategoryFilter == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xxs)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var activeCategories: [HabitIconCategory] {
        let used = Set(viewModel.habitProgresses.map(\.iconCategory))
        return HabitIconCategory.allCases.filter { used.contains($0) }
    }

    private func filterChip(
        label: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background {
                if isSelected {
                    Capsule().fill(DS.Color.tabLife.opacity(DS.Opacity.medium))
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay {
                if isSelected {
                    Capsule()
                        .stroke(DS.Color.tabLife, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? DS.Color.tabLife : .secondary)
    }

    // MARK: - Filtered & Grouped Progresses

    private var filteredProgresses: [HabitProgress] {
        let base = viewModel.habitProgresses.filter { !$0.isAutoLinked }
        guard let filter = selectedCategoryFilter else { return base }
        return base.filter { $0.iconCategory == filter }
    }

    private var groupedProgresses: [(timeOfDay: HabitTimeOfDay, items: [HabitProgress])] {
        let grouped = Dictionary(grouping: filteredProgresses, by: \.timeOfDay)
        return HabitTimeOfDay.allCases
            .compactMap { timeOfDay in
                guard let items = grouped[timeOfDay], !items.isEmpty else { return nil }
                return (timeOfDay: timeOfDay, items: items)
            }
    }

    // MARK: - Sections

    private func habitsSection(fillHeight: Bool = false) -> some View {
        SectionGroup(
            title: "My Habits",
            icon: "checklist",
            iconColor: DS.Color.tabLife,
            fillHeight: fillHeight
        ) {
            if habits.isEmpty {
                EmptyStateView(
                    icon: "checklist",
                    title: "No Habits Yet",
                    message: "Add your first habit to start tracking your daily routine.",
                    actionTitle: "Add Habit",
                    action: {
                        viewModel.resetForm()
                        viewModel.isShowingAddSheet = true
                    }
                )
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    // Category filter chips
                    if activeCategories.count > 1 {
                        categoryFilterSection
                    }

                    // Time-of-day grouped habits
                    ForEach(groupedProgresses, id: \.timeOfDay) { group in
                        if groupedProgresses.count > 1 || group.timeOfDay != .anytime {
                            timeOfDayHeader(group.timeOfDay, count: group.items.count)
                        }

                        ForEach(group.items) { progress in
                            HabitRowView(
                                progress: progress,
                                onToggle: { toggleCheck(habitId: progress.id) },
                                onUpdateValue: { value in updateValue(habitId: progress.id, value: value) },
                                trailingAccessory: AnyView(habitActionsButton(for: progress))
                            )
                            .contextMenu {
                                habitActionItems(for: progress, deferred: true)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("life-section-habits")
        .confirmationDialog(
            "More actions",
            isPresented: Binding(
                get: { actionSelection != nil },
                set: { if !$0 { actionSelection = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let progress = selectedActionProgress {
                habitActionItems(for: progress, deferred: true)
            }
            Button("Cancel", role: .cancel) {
                actionSelection = nil
            }
        }
    }

    private var selectedActionProgress: HabitProgress? {
        guard let actionSelection else { return nil }
        return viewModel.habitProgresses.first { $0.id == actionSelection.id }
    }

    private func habitActionsButton(for progress: HabitProgress) -> some View {
        Button {
            actionSelection = HabitActionSelection(id: progress.id)
        } label: {
            Label("More actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(habitActionsIdentifier(for: progress))
    }

    private func habitActionsIdentifier(for progress: HabitProgress) -> String {
        "life-habit-actions-\(progress.name)"
    }

    @ViewBuilder
    private func habitActionItems(for progress: HabitProgress, deferred: Bool) -> some View {
        let habit = habitsByID[progress.id]

        Button {
            performHabitAction(deferred: deferred) {
                if let habit {
                    viewModel.startEditing(habit)
                }
            }
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .accessibilityIdentifier("life-habit-action-edit")
        .disabled(habit == nil)

        if progress.isCycleBased {
            Button {
                performHabitAction(deferred: deferred) {
                    snoozeCycle(habitId: progress.id, days: 1)
                }
            } label: {
                Label("Snooze 1 Day", systemImage: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
            }
            .accessibilityIdentifier("life-habit-action-snooze")
            .disabled(!progress.isDue)

            Button {
                performHabitAction(deferred: deferred) {
                    skipCycle(habitId: progress.id)
                }
            } label: {
                Label("Skip Cycle", systemImage: "forward.end")
            }
            .accessibilityIdentifier("life-habit-action-skip")
            .disabled(!progress.isDue)
        }

        Button {
            performHabitAction(deferred: deferred) {
                historySelection = HabitHistorySelection(id: progress.id)
            }
        } label: {
            Label("History", systemImage: "clock.badge.checkmark")
        }
        .accessibilityIdentifier("life-habit-action-history")

        Button(role: .destructive) {
            performHabitAction(deferred: deferred) {
                if let habit {
                    withAnimation {
                        habit.isArchived = true
                    }
                }
            }
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .accessibilityIdentifier("life-habit-action-archive")
        .disabled(habit == nil)
    }

    // MARK: - Auto Achievements

    private func autoAchievementsSection(fillHeight: Bool = false) -> some View {
        let groups = autoAchievementGroups
        let customGoals = viewModel.autoLinkedProgresses
        let completedGoals = groups.reduce(0) { $0 + $1.completedCount } + customGoals.filter(\.isCompleted).count
        let totalGoals = groups.reduce(0) { $0 + $1.metrics.count } + customGoals.count
        let useTwoColumnCards = isRegular && !fillHeight

        return SectionGroup(
            title: "Auto Workout Achievements",
            icon: "figure.run",
            iconColor: DS.Color.activity,
            fillHeight: fillHeight
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("HealthKit-based weekly goals (Mon-Sun)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if totalGoals > 0 {
                        Label("\(completedGoals)/\(totalGoals) done", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.positive)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }

                if viewModel.autoExerciseProgresses.isEmpty && customGoals.isEmpty {
                    StandardCard {
                        Text("No HealthKit-linked workouts yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if useTwoColumnCards {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: DS.Spacing.md), GridItem(.flexible())],
                        spacing: DS.Spacing.md
                    ) {
                        ForEach(groups) { group in
                            autoAchievementGroupCard(group)
                        }
                    }
                } else {
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(groups) { group in
                            autoAchievementGroupCard(group)
                        }
                    }
                }

                // Custom auto-linked habits
                if !customGoals.isEmpty {
                    customAutoGoalsGroup(customGoals)
                }
            }
        }
    }

    @State private var pendingArchiveHabitID: UUID?

    private func customAutoGoalsGroup(_ progresses: [HabitProgress]) -> some View {
        let completedCount = progresses.filter(\.isCompleted).count

        return StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "figure.run.circle")
                        .font(.caption)
                        .foregroundStyle(theme.accentColor)
                    Text("Custom Goals")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(completedCount)/\(progresses.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                ForEach(progresses) { progress in
                    customAutoGoalRow(progress)
                }
            }
        }
        .confirmationDialog(
            "Remove this goal?",
            isPresented: Binding(
                get: { pendingArchiveHabitID != nil },
                set: { if !$0 { pendingArchiveHabitID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let id = pendingArchiveHabitID {
                    archiveAutoLinkedHabit(id: id)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingArchiveHabitID = nil
            }
        }
    }

    private func customAutoGoalRow(_ progress: HabitProgress) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: progress.iconCategory.iconName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(progress.name)
                    .font(.caption)
                Spacer()
                if progress.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.positive)
                }
            }
            ProgressView(value: progress.todayValue, total: max(progress.goalValue, 1))
                .tint(progress.isCompleted ? DS.Color.positive : theme.accentColor)
        }
        .contextMenu {
            Button {
                pendingArchiveHabitID = progress.id
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    private func archiveAutoLinkedHabit(id: UUID) {
        guard let habit = habitsByID[id] else { return }
        viewModel.cancelPendingReminders(for: habit)
        habit.isArchived = true
        recalculate()
    }

    private func autoAchievementGroupCard(_ group: AutoAchievementGroup) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: group.icon)
                        .font(.caption)
                        .foregroundStyle(theme.accentColor)
                    Text(group.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(group.completedCount)/\(group.metrics.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                ForEach(group.visibleMetrics) { metric in
                    autoAchievementMetricRow(metric)
                }

                if group.maxStreakWeeks > 0 {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text(String(localized: "Best streak \(group.maxStreakWeeks)w"))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .foregroundStyle(theme.accentColor)
                }
            }
        }
    }

    private func autoAchievementMetricRow(_ metric: LifeAutoAchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xs) {
                Text(shortMetricTitle(metric.id))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if metric.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.positive)
                }
            }
            ProgressView(value: metric.progressRatio)
                .tint(metric.isCompleted ? DS.Color.positive : theme.accentColor)
        }
    }

    private func shortMetricTitle(_ id: String) -> String {
        switch id {
        case "weeklyWorkout5":
            return String(localized: "Workout 5x")
        case "weeklyWorkout7":
            return String(localized: "Workout 7x")
        case "weeklyStrength3":
            return String(localized: "Strength")
        case "weeklyChest3":
            return String(localized: "Chest")
        case "weeklyBack3":
            return String(localized: "Back")
        case "weeklyLowerBody3":
            return String(localized: "Lower Body")
        case "weeklyShoulders3":
            return String(localized: "Shoulders")
        case "weeklyArms3":
            return String(localized: "Arms")
        case "weeklyRunning15km":
            return String(localized: "Running")
        default:
            return String(localized: "Goal")
        }
    }

    private var autoAchievementGroups: [AutoAchievementGroup] {
        let byID = Dictionary(uniqueKeysWithValues: viewModel.autoExerciseProgresses.map { ($0.id, $0) })
        let grouped: [AutoAchievementGroup] = [
            makeAutoGroup(
                id: "routine",
                title: String(localized: "Routine Consistency"),
                icon: "calendar.badge.clock",
                ruleIDs: ["weeklyWorkout5", "weeklyWorkout7"],
                byID: byID
            ),
            makeAutoGroup(
                id: "strength",
                title: String(localized: "Strength Split"),
                icon: "dumbbell.fill",
                ruleIDs: ["weeklyStrength3", "weeklyChest3", "weeklyBack3", "weeklyLowerBody3", "weeklyShoulders3", "weeklyArms3"],
                byID: byID
            ),
            makeAutoGroup(
                id: "running",
                title: String(localized: "Running Distance"),
                icon: "figure.run",
                ruleIDs: ["weeklyRunning15km"],
                byID: byID
            )
        ]

        return grouped.filter { !$0.metrics.isEmpty }
    }

    private func makeAutoGroup(
        id: String,
        title: String,
        icon: String,
        ruleIDs: [String],
        byID: [String: LifeAutoAchievementProgress]
    ) -> AutoAchievementGroup {
        let metrics = ruleIDs.compactMap { byID[$0] }
        return AutoAchievementGroup(id: id, title: title, icon: icon, metrics: metrics)
    }

    private struct AutoAchievementGroup: Identifiable {
        let id: String
        let title: String
        let icon: String
        let metrics: [LifeAutoAchievementProgress]

        var completedCount: Int {
            metrics.filter(\.isCompleted).count
        }

        var maxStreakWeeks: Int {
            metrics.map(\.streakWeeks).max() ?? 0
        }

        var visibleMetrics: [LifeAutoAchievementProgress] {
            if id == "strength" {
                let filtered = metrics.filter { $0.id == "weeklyStrength3" || $0.currentValue > 0 || $0.isCompleted }
                return filtered.isEmpty ? Array(metrics.prefix(1)) : filtered
            }
            return metrics
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HeroCard(tintColor: DS.Color.tabLife) {
            HStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                completionRing

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Today's Progress")
                            .font(isRegular ? .title3 : .headline)
                            .fontWeight(.semibold)

                        Image(systemName: completionStatusIcon)
                            .font(.subheadline)
                            .foregroundStyle(completionStatusColor)
                    }

                    Text(viewModel.heroNarrative)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text("\(viewModel.completedCount)")
                            .font(DS.Typography.cardScore)
                            .foregroundStyle(theme.heroTextGradient)
                            .contentTransition(.numericText())
                        Text("/ \(viewModel.totalActiveCount)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Life progress \(viewModel.completedCount) of \(viewModel.totalActiveCount)"))
        .sensoryFeedback(.impact(weight: .light), trigger: heroAppeared)
        .onAppear {
            guard !heroAppeared else { return }
            heroAppeared = true
        }
    }

    private var completionStatusIcon: String {
        let total = viewModel.totalActiveCount
        if total == 0 { return "circle.dashed" }
        if viewModel.completedCount >= total { return "checkmark.circle.fill" }
        if viewModel.completedCount > 0 { return "circle.lefthalf.filled" }
        return "circle"
    }

    private var completionStatusColor: Color {
        let total = viewModel.totalActiveCount
        if total == 0 { return .secondary }
        if viewModel.completedCount >= total { return DS.Color.positive }
        if viewModel.completedCount > 0 { return DS.Color.tabLife }
        return .secondary
    }

    private var completionRing: some View {
        let total = Swift.max(viewModel.totalActiveCount, 1)
        let progress = Double(viewModel.completedCount) / Double(total)
        return ProgressRingView(
            progress: progress,
            ringColor: DS.Color.tabLife,
            lineWidth: isRegular ? 10 : 8,
            size: isRegular ? 80 : 64
        )
        .overlay {
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(theme.sandColor)
                .contentTransition(.numericText())
        }
    }

    private func timeOfDayHeader(_ timeOfDay: HabitTimeOfDay, count: Int) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: timeOfDay.iconName)
                .font(.caption)
                .foregroundStyle(DS.Color.tabLife)
            Text(timeOfDay.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Actions

    private func todayLogs(for habit: HabitDefinition, date: Date = Date()) -> [HabitLog] {
        let calendar = Calendar.current
        let relationshipLogs = (habit.logs ?? []).filter { calendar.isDate($0.date, inSameDayAs: date) }
        if !relationshipLogs.isEmpty {
            return relationshipLogs
        }

        return habitLogs.filter {
            $0.habitDefinition?.id == habit.id && calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    private func insertLog(_ log: HabitLog, into habit: HabitDefinition) {
        LifeHabitLogSync.insert(log, into: habit)
        modelContext.insert(log)
    }

    private func deleteLogs(_ logs: [HabitLog], from habit: HabitDefinition) {
        guard !logs.isEmpty else { return }

        LifeHabitLogSync.delete(logs, from: habit)

        for log in logs {
            modelContext.delete(log)
        }
    }

    private func toggleCheck(habitId: UUID) {
        guard let habit = habitsByID[habitId] else { return }

        if let progress = viewModel.habitProgresses.first(where: { $0.id == habitId }), progress.isCycleBased {
            guard progress.canCompleteCycle else { return }
            deleteLogs(todayLogs(for: habit), from: habit)
            if let log = viewModel.createCycleActionLog(for: habit, action: .complete) {
                insertLog(log, into: habit)
                viewModel.didFinishSaving()
                // Cancel pending reminders on early completion, reschedule for next cycle
                viewModel.cancelPendingReminders(for: habit)
                viewModel.refreshReminderSchedule(for: habit)
            }
            recalculate()
            return
        }

        let existingLogs = todayLogs(for: habit)

        if !existingLogs.isEmpty {
            // Toggle off: remove log
            withAnimation {
                deleteLogs(existingLogs, from: habit)
            }
            viewModel.refreshReminderSchedule(for: habit)
        } else {
            // Toggle on: add log
            if let log = viewModel.createValidatedLog(for: habit, value: 1.0) {
                insertLog(log, into: habit)
                viewModel.didFinishSaving()
                viewModel.refreshReminderSchedule(for: habit)
            }
        }
        recalculate()
    }

    private func updateValue(habitId: UUID, value: Double) {
        guard let habit = habitsByID[habitId] else { return }

        // Remove existing today logs
        deleteLogs(todayLogs(for: habit), from: habit)

        // Add new log with updated value
        if value > 0 {
            if let log = viewModel.createValidatedLog(for: habit, value: value) {
                insertLog(log, into: habit)
                viewModel.didFinishSaving()
                viewModel.refreshReminderSchedule(for: habit)
            }
        }
        recalculate()
    }

    private func skipCycle(habitId: UUID) {
        guard let habit = habitsByID[habitId] else { return }
        guard habit.frequency.intervalDays != nil else { return }
        guard let snapshot = viewModel.cycleSnapshot(for: habit), snapshot.isDue else { return }

        if let log = viewModel.createCycleActionLog(for: habit, action: .skip) {
            insertLog(log, into: habit)
            viewModel.didFinishSaving()
            viewModel.refreshReminderSchedule(for: habit)
            recalculate()
        }
    }

    private func snoozeCycle(habitId: UUID, days: Int) {
        guard let habit = habitsByID[habitId] else { return }
        guard habit.frequency.intervalDays != nil else { return }
        guard let snapshot = viewModel.cycleSnapshot(for: habit), snapshot.isDue else { return }
        guard let snoozeDate = viewModel.suggestedSnoozeDate(for: habit, days: days) else { return }
        guard let nextDueDate = snapshot.nextDueDate else { return }
        guard snoozeDate > nextDueDate else { return }

        if let log = viewModel.createCycleActionLog(for: habit, action: .snooze, date: snoozeDate) {
            insertLog(log, into: habit)
            viewModel.didFinishSaving()
            viewModel.refreshReminderSchedule(for: habit)
            recalculate()
        }
    }

    private func recalculate() {
        // Correction #68: rebuild O(1) lookup dictionary
        // Correction #104: uniquingKeysWith instead of uniqueKeysWithValues
        habitsByID = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        viewModel.calculateProgresses(
            habits: habits,
            todayExerciseExists: cachedTodayExerciseExists
        )
        viewModel.calculateAutoExerciseProgresses(
            exerciseRecords: exerciseRecords
        )
        recalculateAnalytics()
    }

    private func recalculateAnalytics() {
        let logSnapshots = habitLogs.map { log in
            HabitLogSnapshot(
                habitID: log.habitDefinition?.id ?? UUID(),
                date: log.date,
                value: log.value,
                memo: log.memo
            )
        }
        let habitSnapshots = habits.map { habit in
            HabitSnapshot(
                id: habit.id,
                name: habit.name,
                goalValue: habit.goalValue,
                frequencyTypeRaw: habit.frequencyTypeRaw,
                weeklyTargetDays: habit.weeklyTargetDays
            )
        }

        weeklyRates = HabitAnalyticsService.weeklyCompletionRates(
            logs: logSnapshots, habits: habitSnapshots
        )
        monthlyRates = HabitAnalyticsService.monthlyCompletionRates(
            logs: logSnapshots, habits: habitSnapshots
        )
        heatmapData = HabitAnalyticsService.dailyCompletionCounts(
            logs: logSnapshots
        )
        weeklyReport = HabitAnalyticsService.weeklyReport(
            logs: logSnapshots, habits: habitSnapshots
        )
    }

    private func performHabitAction(deferred: Bool, _ action: @escaping () -> Void) {
        if deferred {
            performDeferredHabitAction(action)
        } else {
            action()
        }
    }

    private func performDeferredHabitAction(_ action: @escaping () -> Void) {
        Task { @MainActor in
            // Let the current menu/dialog dismiss before mutating the host row or opening sheets.
            await Task.yield()
            action()
        }
    }
}

private struct HabitHistorySheet: View {
    let habitName: String
    let iconCategory: HabitIconCategory
    let habitType: HabitType
    let entries: [LifeViewModel.HabitHistoryEntry]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with single close button
            header

            Divider()

            if entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .background { SheetWaveBackground() }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("life-habit-history-screen")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: iconCategory.iconName)
                .font(.title3)
                .foregroundStyle(iconCategory.themeColor)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(iconCategory.themeColor.opacity(DS.Opacity.light))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(habitName)
                    .font(.headline)
                Text(String(localized: "\(entries.count) records"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("life-habit-history-close")
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Entry List

    // Hoist today's startOfDay outside ForEach to avoid per-row Calendar allocation
    private var todayStartOfDay: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var entryList: some View {
        let today = todayStartOfDay
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    entryRow(entry, today: today)

                    if entry.id != entries.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
        }
    }

    private func entryRow(_ entry: LifeViewModel.HabitHistoryEntry, today: Date) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            // Action icon
            Image(systemName: iconName(for: entry.action))
                .font(.body)
                .foregroundStyle(color(for: entry.action))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(color(for: entry.action).opacity(0.12))
                }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(actionTitle(for: entry))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if entry.action == .complete {
                    Text(valueDescription(for: entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(relativeDate(entry.date, today: today))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("life-habit-history-row-\(entry.id.uuidString.prefix(8))")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No History")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Complete this habit to start building your history")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(DS.Spacing.xl)
        .accessibilityIdentifier("life-habit-history-empty")
    }

    // MARK: - Helpers

    private func actionTitle(for entry: LifeViewModel.HabitHistoryEntry) -> String {
        switch entry.action {
        case .complete: String(localized: "Completed")
        case .skip: String(localized: "Skipped")
        case .snooze: String(localized: "Snoozed")
        }
    }

    private func valueDescription(for entry: LifeViewModel.HabitHistoryEntry) -> String {
        let value = max(0, Int(entry.value))
        let goal = max(0, Int(entry.goalValue))
        switch entry.habitType {
        case .check:
            return String(localized: "Done")
        case .duration:
            // goalUnit is user-entered free-text; "min" fallback is localized
            let unit = entry.goalUnit ?? String(localized: "min")
            return String(localized: "\(value)/\(goal) \(unit)")
        case .count:
            let unit = entry.goalUnit ?? ""
            if unit.isEmpty {
                return "\(value)/\(goal)"
            }
            return String(localized: "\(value)/\(goal) \(unit)")
        }
    }

    private func relativeDate(_ date: Date, today: Date) -> String {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: target, to: today).day ?? 0

        switch days {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Yesterday")
        default: return String(localized: "\(days) days ago")
        }
    }

    private func iconName(for action: HabitCycleAction) -> String {
        switch action {
        case .complete: "checkmark.circle.fill"
        case .skip: "forward.end.fill"
        case .snooze: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        }
    }

    private func color(for action: HabitCycleAction) -> Color {
        switch action {
        case .complete: DS.Color.positive
        case .skip: DS.Color.negative
        case .snooze: DS.Color.tabWellness
        }
    }
}

// MARK: - Today Exercise Check (Isolated @Query)
// Avoids unbounded ExerciseRecord fetch in parent view.

private struct TodayExerciseCheckView: View {
    @Query private var recentRecords: [ExerciseRecord]

    @Binding var exists: Bool

    init(exists: Binding<Bool>) {
        _exists = exists
        var descriptor = FetchDescriptor<ExerciseRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        _recentRecords = Query(descriptor)
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: recentRecords.count) { _, _ in
                updateCheck()
            }
            .onAppear {
                updateCheck()
            }
    }

    private func updateCheck() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Check only first few records (sorted by date desc) — today's records are at the front
        exists = recentRecords.contains { calendar.isDate($0.date, inSameDayAs: today) }
    }
}

#Preview {
    NavigationStack {
        LifeView()
    }
    .modelContainer(for: [HabitDefinition.self, HabitLog.self, ExerciseRecord.self], inMemory: true)
}
