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

    @Query(
        filter: #Predicate<ExerciseRecord> { _ in true },
        sort: \ExerciseRecord.date,
        order: .reverse
    ) private var exerciseRecords: [ExerciseRecord]

    @Bindable var viewModel: LifeViewModel

    @Environment(\.modelContext) private var modelContext

    private var todayExerciseExists: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return exerciseRecords.contains { calendar.isDate($0.date, inSameDayAs: today) }
    }

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

            // Habit rows
            ForEach(viewModel.habitProgresses) { progress in
                HabitRowView(
                    progress: progress,
                    onToggle: { toggleCheck(habitId: progress.id) },
                    onUpdateValue: { value in updateValue(habitId: progress.id, value: value) }
                )
                .contextMenu {
                    Button {
                        if let habit = habits.first(where: { $0.id == progress.id }) {
                            viewModel.startEditing(habit)
                        }
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        if let habit = habits.first(where: { $0.id == progress.id }) {
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

        Color.clear
            .frame(height: 0)
            .onChange(of: habits.count) { _, _ in
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
        guard let habit = habits.first(where: { $0.id == habitId }) else { return }
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
        guard let habit = habits.first(where: { $0.id == habitId }) else { return }
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
        viewModel.calculateProgresses(
            habits: habits,
            todayExerciseExists: todayExerciseExists
        )
    }
}

#Preview {
    NavigationStack {
        LifeView()
    }
    .modelContainer(for: [HabitDefinition.self, HabitLog.self, ExerciseRecord.self], inMemory: true)
}
