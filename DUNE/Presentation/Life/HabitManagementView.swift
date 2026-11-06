import SwiftUI
import SwiftData

struct HabitManagementView: View {
    @Query(
        filter: #Predicate<HabitDefinition> { !$0.isArchived },
        sort: \HabitDefinition.sortOrder
    ) private var activeHabits: [HabitDefinition]

    @Query(
        filter: #Predicate<HabitDefinition> { $0.isArchived },
        sort: \HabitDefinition.createdAt, order: .reverse
    ) private var archivedHabits: [HabitDefinition]

    @Query(sort: \HabitLog.date, order: .reverse) private var allLogs: [HabitLog]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var filter: HabitFilter = .active
    @State private var historySelection: HabitHistoryItem?

    private enum HabitFilter: String, CaseIterable {
        case active
        case archived

        var displayName: String {
            switch self {
            case .active: String(localized: "Active")
            case .archived: String(localized: "Archived")
            }
        }
    }

    private struct HabitHistoryItem: Identifiable {
        let id: UUID
        let name: String
        let iconCategory: HabitIconCategory
        let habitType: HabitType
    }

    private var displayedHabits: [HabitDefinition] {
        switch filter {
        case .active: activeHabits
        case .archived: archivedHabits
        }
    }

    // Cached snapshots to avoid recomputing per-row (P2 review fix)
    @State private var cachedLogSnapshots: [HabitLogSnapshot] = []
    @State private var cachedStats: [UUID: (total: Int, bestStreak: Int)] = [:]

    private var logSignature: Int {
        var hasher = Hasher()
        for log in allLogs {
            hasher.combine(log.habitDefinition?.id)
            hasher.combine(log.date)
            hasher.combine(log.value)
            hasher.combine(log.memo)
            hasher.combine(log.completedAt)
        }
        for habit in activeHabits + archivedHabits {
            hasher.combine(habit.id)
            hasher.combine(habit.goalValue)
        }
        return hasher.finalize()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                managementHero
                filterPicker

                if displayedHabits.isEmpty {
                    emptyState
                } else {
                    habitList
                }
            }
            .padding(DS.Spacing.lg)
        }
        .task(id: logSignature) {
            let snapshots = HabitLogResolution.resolve(allLogs).filter { !HabitLogResolution.isZeroTombstone($0) }.map { log in
                HabitLogSnapshot(
                    habitID: log.habitDefinition?.id ?? UUID(),
                    date: log.date,
                    value: log.value,
                    memo: log.memo
                )
            }
            cachedLogSnapshots = snapshots

            let allHabits = activeHabits + archivedHabits
            var stats: [UUID: (total: Int, bestStreak: Int)] = [:]
            for habit in allHabits {
                stats[habit.id] = (
                    total: HabitStreakService.totalCompletions(logs: snapshots, for: habit.id, goalValue: habit.goalValue),
                    bestStreak: HabitStreakService.longestStreak(logs: snapshots, for: habit.id, goalValue: habit.goalValue)
                )
            }
            cachedStats = stats
        }
        .scrollBounceBehavior(.basedOnSize)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Habits")
        .sheet(item: $historySelection) { selection in
            HabitHistoryDetailSheet(
                habitName: selection.name,
                iconCategory: selection.iconCategory,
                habitType: selection.habitType,
                logs: cachedLogSnapshots.filter { $0.habitID == selection.id }
            )
        }
        .accessibilityIdentifier("habit-management-screen")
    }

    private var managementHero: some View {
        HeroCard(tintColor: DS.Color.warmGlow) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: filter == .active ? "checklist" : "archivebox")
                        .accessibilityHidden(true)
                    Text("Habits")
                        .accessibilityIdentifier("habit-management-hero-title")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(displayedHabits.count, format: .number)
                        .font(DS.Typography.heroScore)
                        .accessibilityIdentifier("habit-management-hero-count")
                    Text(filter.displayName)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("habit-management-hero-filter")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(HabitFilter.allCases, id: \.self) { filterOption in
                let count = filterOption == .active ? activeHabits.count : archivedHabits.count
                Text("\(filterOption.displayName) (\(count))")
                    .tag(filterOption)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("habit-management-filter")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Group {
            if filter == .active {
                EmptyStateView(
                    icon: "checklist",
                    title: "No Active Habits",
                    message: "Add habits from the Life tab to start tracking."
                )
            } else {
                EmptyStateView(
                    icon: "archivebox",
                    title: "No Archived Habits",
                    message: "Archived habits will appear here."
                )
            }
        }
        .padding(.top, DS.Spacing.xxl)
    }

    // MARK: - Habit List

    private var habitList: some View {
        LazyVStack(spacing: DS.Spacing.sm) {
            ForEach(displayedHabits) { habit in
                habitRow(habit)
            }
        }
    }

    private func habitRow(_ habit: HabitDefinition) -> some View {
        let stats = cachedStats[habit.id]
        let totalCount = stats?.total ?? 0
        let bestStreak = stats?.bestStreak ?? 0

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
        return StandardCard {
            layout {
                // Icon
                Image(systemName: habit.iconCategory.iconName)
                    .font(.title3)
                    .foregroundStyle(colorScheme == .light
                        ? habit.iconCategory.themeColor.mix(with: .black, by: 0.35)
                        : habit.iconCategory.themeColor)
                    .frame(minWidth: 40, minHeight: 40)
                    .background(habit.iconCategory.themeColor.opacity(DS.Opacity.light), in: Circle())

                // Name + stats
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Label(
                            String(localized: "\(totalCount) times"),
                            systemImage: "checkmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if bestStreak > 0 {
                            Label(
                                String(localized: "\(bestStreak) day streak"),
                                systemImage: "flame"
                            )
                            .font(.caption)
                            .foregroundStyle(DS.Color.warmGlow)
                        }

                        Text(habit.createdAt.formatted(.dateTime.month(.abbreviated).year()))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)

                // Actions
                if filter == .archived {
                    archivedActions(habit)
                }
            }
        }
    }

    // MARK: - Archived Actions

    private func archivedActions(_ habit: HabitDefinition) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                historySelection = HabitHistoryItem(
                    id: habit.id,
                    name: habit.name,
                    iconCategory: habit.iconCategory,
                    habitType: habit.habitType
                )
            } label: {
                Image(systemName: "clock.badge.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "History"))
            .accessibilityIdentifier("habit-management-history-\(habit.name)")

            Button {
                restoreHabit(habit)
            } label: {
                Text("Restore")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(DS.Color.positive.opacity(DS.Opacity.light), in: Capsule())
                    .foregroundStyle(DS.Color.positive)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("habit-management-restore-\(habit.name)")
        }
    }

    // MARK: - Actions

    private func restoreHabit(_ habit: HabitDefinition) {
        withAnimation {
            habit.isArchived = false
            habit.sortOrder = activeHabits.count
        }
    }
}

// MARK: - History Detail Sheet (reuses existing pattern)

private struct HabitHistoryDetailSheet: View {
    let habitName: String
    let iconCategory: HabitIconCategory
    let habitType: HabitType
    let logs: [HabitLogSnapshot]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private static let skipMemoMarker = "[dune-life-cycle-skip]"
    private static let snoozeMemoMarker = "[dune-life-cycle-snooze]"

    private var sortedEntries: [(date: Date, value: Double, action: String)] {
        logs.sorted { $0.date > $1.date }.map { log in
            let action: String
            if log.memo == Self.skipMemoMarker {
                action = "skip"
            } else if log.memo == Self.snoozeMemoMarker {
                action = "snooze"
            } else {
                action = "complete"
            }
            return (date: log.date, value: log.value, action: action)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider()

                if sortedEntries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("habit-management-history-scroll")
        .background { SheetWaveBackground() }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HeroCard(tintColor: iconCategory.themeColor) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: iconCategory.iconName)
                        .font(.title3)
                        .foregroundStyle(colorScheme == .light
                            ? iconCategory.themeColor.mix(with: .black, by: 0.35)
                            : iconCategory.themeColor)
                        .frame(minWidth: 40, minHeight: 40)
                        .background(iconCategory.themeColor.opacity(DS.Opacity.light), in: Circle())
                        .accessibilityHidden(true)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text(habitName)
                            .font(DS.Typography.sectionTitle)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("habit-management-history-screen")
                    }
                    Spacer(minLength: 0)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 48, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("habit-management-history-close")
                }
                if dynamicTypeSize.isAccessibilitySize {
                    Text(habitName)
                        .font(DS.Typography.sectionTitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("habit-management-history-screen")
                }
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "clock.arrow.circlepath")
                        .accessibilityHidden(true)
                    Text("History")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.md)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No History")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }

    private var entryList: some View {
        LazyVStack(spacing: DS.Spacing.sm) {
            ForEach(Array(sortedEntries.enumerated()), id: \.offset) { _, entry in
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
                    : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
                layout {
                    Image(systemName: actionIcon(entry.action))
                        .font(.subheadline)
                        .foregroundStyle(actionColor(entry.action))
                        .frame(minWidth: 32, minHeight: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTitle(entry.action))
                            .font(.subheadline.weight(.medium))

                        if habitType != .check, entry.action == "complete" {
                            Text(formattedValue(entry.value))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                    Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Spacing.sm)
            }
        }
        .padding(.horizontal)
    }

    private func actionIcon(_ action: String) -> String {
        switch action {
        case "skip": "forward.end"
        case "snooze": "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        default: "checkmark.circle.fill"
        }
    }

    private func actionColor(_ action: String) -> Color {
        switch action {
        case "skip": .orange
        case "snooze": .blue
        default: DS.Color.positive
        }
    }

    private func actionTitle(_ action: String) -> String {
        switch action {
        case "skip": String(localized: "Skipped")
        case "snooze": String(localized: "Snoozed")
        default: String(localized: "Completed")
        }
    }

    private func formattedValue(_ value: Double) -> String {
        switch habitType {
        case .duration:
            let minutes = Int(value)
            return String(localized: "\(minutes) min")
        case .count:
            let count = Int(value)
            return String(localized: "\(count)x")
        case .check:
            return ""
        }
    }
}
