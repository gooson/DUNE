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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme

    private let scrollToTopSignal: Int
    private let refreshSignal: Int

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
        .background { TabWaveBackground() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.resetForm()
                    viewModel.isShowingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add habit")
                .accessibilityIdentifier("life-toolbar-add")
            }
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
    @State private var heroAppeared = false

    private struct HabitHistorySelection: Identifiable {
        let id: UUID
    }

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Hero: completion rate
            heroSection
                .accessibilityIdentifier("life-hero-progress")

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

        // Isolated exercise record check — own @Query to avoid parent re-layout
        TodayExerciseCheckView(exists: $cachedTodayExerciseExists)

        Color.clear
            .frame(height: 0)
            .onChange(of: habits.count) { _, _ in
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
                    ForEach(viewModel.habitProgresses) { progress in
                        HabitRowView(
                            progress: progress,
                            onToggle: { toggleCheck(habitId: progress.id) },
                            onUpdateValue: { value in updateValue(habitId: progress.id, value: value) }
                        )
                        .contextMenu {
                            habitContextMenu(for: progress)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("life-section-habits")
    }

    @ViewBuilder
    private func habitContextMenu(for progress: HabitProgress) -> some View {
        Button {
            if let habit = habitsByID[progress.id] {
                viewModel.startEditing(habit)
            }
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        if progress.isCycleBased {
            Button {
                snoozeCycle(habitId: progress.id, days: 1)
            } label: {
                Label("Snooze 1 Day", systemImage: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
            }
            .disabled(!progress.isDue)

            Button {
                skipCycle(habitId: progress.id)
            } label: {
                Label("Skip Cycle", systemImage: "forward.end")
            }
            .disabled(!progress.isDue)

            Button {
                historySelection = HabitHistorySelection(id: progress.id)
            } label: {
                Label("History", systemImage: "clock.badge.checkmark")
            }
        }

        Button(role: .destructive) {
            if let habit = habitsByID[progress.id] {
                withAnimation {
                    habit.isArchived = true
                }
            }
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
    }

    // MARK: - Auto Achievements

    private func autoAchievementsSection(fillHeight: Bool = false) -> some View {
        let groups = autoAchievementGroups
        let completedGoals = groups.reduce(0) { $0 + $1.completedCount }
        let totalGoals = groups.reduce(0) { $0 + $1.metrics.count }
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

                if viewModel.autoExerciseProgresses.isEmpty {
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
            }
        }
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
    }
}

private struct HabitHistorySheet: View {
    let habitName: String
    let entries: [LifeViewModel.HabitHistoryEntry]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                Text(habitName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)

                if entries.isEmpty {
                    EmptyStateView(
                        icon: "clock.badge.questionmark",
                        title: "No History",
                        message: "No cycle actions recorded yet.",
                        actionTitle: "Close",
                        action: { dismiss() }
                    )
                } else {
                    List(entries) { entry in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: iconName(for: entry.action))
                                .foregroundStyle(color(for: entry.action))
                                .frame(width: 20)
                            Text(title(for: entry.action))
                                .font(.subheadline)
                            Spacer()
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .englishNavigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func title(for action: HabitCycleAction) -> String {
        switch action {
        case .complete: String(localized: "Completed")
        case .skip: String(localized: "Skipped")
        case .snooze: String(localized: "Snoozed")
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
