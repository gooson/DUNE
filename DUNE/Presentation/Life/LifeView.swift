import SwiftUI
import SwiftData

struct LifeView: View {
    @State private var viewModel = LifeViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass

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
                    HabitListQueryView(viewModel: viewModel)
                }
                .padding(isRegular ? DS.Spacing.xxl : DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
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
                            viewModel.didFinishSaving()
                            viewModel.isShowingEditSheet = false
                            viewModel.resetForm()
                        }
                    }
                )
            }
        }
        .navigationTitle("Life")
    }
}

// MARK: - Isolated @Query Child View
// Extracted to prevent SwiftData @Query observation from triggering parent ScrollView re-layout (Correction #179).

private struct HabitListQueryView: View {
    @Query(
        filter: #Predicate<HabitDefinition> { !$0.isArchived },
        sort: \HabitDefinition.sortOrder
    ) private var habits: [HabitDefinition]

    @Bindable var viewModel: LifeViewModel

    @Environment(\.modelContext) private var modelContext

    // Correction #68: O(1) lookup instead of O(N) per row
    @State private var habitsByID: [UUID: HabitDefinition] = [:]
    // Correction #102: cached today exercise check (avoid body-path Calendar ops)
    @State private var cachedTodayExerciseExists = false

    var body: some View {
        if habits.isEmpty {
            EmptyStateView(
                icon: "checklist",
                title: "No Habits Yet",
                message: "Add your first habit to start tracking your daily routine."
            )
        } else {
            // Hero: completion rate
            heroSection
                .accessibilityIdentifier("life-hero-progress")

            // Habit rows
            ForEach(viewModel.habitProgresses) { progress in
                HabitRowView(
                    progress: progress,
                    onToggle: { toggleCheck(habitId: progress.id) },
                    onUpdateValue: { value in updateValue(habitId: progress.id, value: value) }
                )
                .contextMenu {
                    Button {
                        if let habit = habitsByID[progress.id] {
                            viewModel.startEditing(habit)
                        }
                    } label: {
                        Label("Edit", systemImage: "pencil")
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
            }
        }

        // Isolated exercise record check — own @Query to avoid parent re-layout
        TodayExerciseCheckView(exists: $cachedTodayExerciseExists)

        Color.clear
            .frame(height: 0)
            .onChange(of: habits.count) { _, _ in
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
    }

    // MARK: - Hero

    private var heroSection: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Today's Progress")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            Text("\(viewModel.completedCount)")
                                .font(DS.Typography.cardScore)
                                .foregroundStyle(DS.Gradient.heroText)
                            Text("/ \(viewModel.totalActiveCount)")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    completionRing
                }
            }
        }
    }

    private var completionRing: some View {
        let total = Swift.max(viewModel.totalActiveCount, 1)
        let progress = Double(viewModel.completedCount) / Double(total)
        return ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    DS.Color.positive,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(width: 48, height: 48)
        .animation(DS.Animation.standard, value: viewModel.completedCount)
    }

    // MARK: - Actions

    private func toggleCheck(habitId: UUID) {
        guard let habit = habitsByID[habitId] else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let existingLog = (habit.logs ?? []).first { calendar.isDate($0.date, inSameDayAs: today) }

        if let log = existingLog {
            // Toggle off: remove log
            withAnimation {
                modelContext.delete(log)
            }
        } else {
            // Toggle on: add log
            if let log = viewModel.createValidatedLog(for: habit, value: 1.0) {
                log.habitDefinition = habit
                modelContext.insert(log)
                viewModel.didFinishSaving()
            }
        }
        recalculate()
    }

    private func updateValue(habitId: UUID, value: Double) {
        guard let habit = habitsByID[habitId] else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Remove existing today logs
        let existingLogs = (habit.logs ?? []).filter { calendar.isDate($0.date, inSameDayAs: today) }
        for log in existingLogs {
            modelContext.delete(log)
        }

        // Add new log with updated value
        if value > 0 {
            if let log = viewModel.createValidatedLog(for: habit, value: value) {
                log.habitDefinition = habit
                modelContext.insert(log)
                viewModel.didFinishSaving()
            }
        }
        recalculate()
    }

    private func recalculate() {
        // Correction #68: rebuild O(1) lookup dictionary
        // Correction #104: uniquingKeysWith instead of uniqueKeysWithValues
        habitsByID = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        viewModel.calculateProgresses(
            habits: habits,
            todayExerciseExists: cachedTodayExerciseExists
        )
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
