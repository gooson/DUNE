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

    private var logSnapshots: [HabitLogSnapshot] {
        allLogs.map { log in
            HabitLogSnapshot(
                habitID: log.habitDefinition?.id ?? UUID(),
                date: log.date,
                value: log.value,
                memo: log.memo
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                filterPicker

                if displayedHabits.isEmpty {
                    emptyState
                } else {
                    habitList
                }
            }
            .padding(DS.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Habits")
        .sheet(item: $historySelection) { selection in
            HabitHistoryDetailSheet(
                habitName: selection.name,
                iconCategory: selection.iconCategory,
                habitType: selection.habitType,
                logs: logSnapshots.filter { $0.habitID == selection.id }
            )
        }
        .accessibilityIdentifier("habit-management-screen")
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
        let totalCount = HabitStreakService.totalCompletions(logs: logSnapshots, for: habit.id)
        let bestStreak = HabitStreakService.longestStreak(logs: logSnapshots, for: habit.id)

        return HStack(spacing: DS.Spacing.md) {
            // Icon
            Image(systemName: habit.iconCategory.iconName)
                .font(.title3)
                .foregroundStyle(habit.iconCategory.themeColor)
                .frame(width: 36, height: 36)
                .background(habit.iconCategory.themeColor.opacity(DS.Opacity.light), in: Circle())

            // Name + stats
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.sm) {
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

            Spacer()

            // Actions
            if filter == .archived {
                archivedActions(habit)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityIdentifier("habit-management-row-\(habit.name)")
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
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "History"))

            Button {
                restoreHabit(habit)
            } label: {
                Text("Restore")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(DS.Color.positive.opacity(DS.Opacity.light), in: Capsule())
                    .foregroundStyle(DS.Color.positive)
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
        VStack(spacing: 0) {
            header
            Divider()

            if sortedEntries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .background { SheetWaveBackground() }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("habit-management-history-screen")
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: iconCategory.iconName)
                .font(.title3)
                .foregroundStyle(iconCategory.themeColor)
                .frame(width: 36, height: 36)
                .background(iconCategory.themeColor.opacity(DS.Opacity.light), in: Circle())

            VStack(alignment: .leading) {
                Text(habitName)
                    .font(.headline)
                Text("History")
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
            .accessibilityLabel("Close")
        }
        .padding()
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
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(Array(sortedEntries.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: actionIcon(entry.action))
                            .font(.subheadline)
                            .foregroundStyle(actionColor(entry.action))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(actionTitle(entry.action))
                                .font(.subheadline.weight(.medium))

                            if habitType != .check, entry.action == "complete" {
                                Text(formattedValue(entry.value))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(DS.Spacing.sm)
                }
            }
            .padding(.horizontal)
        }
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
            return "\(minutes) min"
        case .count:
            return "\(Int(value))x"
        case .check:
            return ""
        }
    }
}
