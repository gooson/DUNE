import SwiftUI

struct HabitRowView: View {
    let progress: HabitProgress
    let onToggle: () -> Void
    let onUpdateValue: (Double) -> Void
    let trailingAccessory: AnyView?

    @Environment(\.appTheme) private var theme
    @State private var inputText: String = ""
    @State private var isEditing = false

    init(
        progress: HabitProgress,
        onToggle: @escaping () -> Void,
        onUpdateValue: @escaping (Double) -> Void,
        trailingAccessory: AnyView? = nil
    ) {
        self.progress = progress
        self.onToggle = onToggle
        self.onUpdateValue = onUpdateValue
        self.trailingAccessory = trailingAccessory
    }

    var body: some View {
        Group {
            if isWholeRowToggle {
                cardContent
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isToggleDisabled else { return }
                        onToggle()
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        guard !isToggleDisabled else { return }
                        onToggle()
                    }
                    .accessibilityIdentifier("life-habit-toggle")
            } else {
                cardContent
            }
        }
    }

    private var isWholeRowToggle: Bool {
        progress.isCycleBased || progress.type == .check
    }

    private var isToggleDisabled: Bool {
        if progress.isCycleBased {
            return !progress.canCompleteCycle
        }
        return progress.isAutoCompleted
    }

    private var cardContent: some View {
        StandardCard {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                iconView

                // Content
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text(progress.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        HStack(spacing: DS.Spacing.xs) {
                            streakBadge

                            if let trailingAccessory {
                                trailingAccessory
                            }
                        }
                    }

                    habitInput

                    if progress.isCycleBased {
                        cycleMetadata
                    }
                }
            }
        }
    }

    // MARK: - Icon

    private var iconView: some View {
        Image(systemName: progress.iconCategory.iconName)
            .font(.title3)
            .foregroundStyle(progress.isCompleted ? progress.iconCategory.themeColor : .secondary)
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(progress.iconCategory.themeColor.opacity(progress.isCompleted ? DS.Opacity.medium : DS.Opacity.subtle))
            }
    }

    // MARK: - Streak Badge

    @ViewBuilder
    private var streakBadge: some View {
        if progress.streak > 0 {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                Text("\(progress.streak)")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(theme.accentColor)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background {
                Capsule()
                    .fill(theme.accentColor.opacity(DS.Opacity.light))
            }
        }
    }

    // MARK: - Habit Input (type-specific)

    @ViewBuilder
    private var habitInput: some View {
        if progress.isCycleBased {
            cycleCheckInput
        } else {
            switch progress.type {
            case .check:
                checkInput
            case .duration:
                valueInput(unit: progress.goalUnit ?? "min")
            case .count:
                countInput
            }
        }
    }

    // MARK: - Check Type

    private var checkInput: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: progress.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(progress.isCompleted ? AnyShapeStyle(DS.Color.positive) : AnyShapeStyle(.tertiary))

            Text(progress.isCompleted ? String(localized: "Done") : String(localized: "Tap to complete"))
                .font(.caption)
                .foregroundStyle(progress.isCompleted ? .primary : .secondary)

            if progress.isAutoCompleted {
                Text("Auto")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 1)
                    .background {
                        Capsule().fill(.quaternary)
                    }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var cycleCheckInput: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: progress.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(progress.isCompleted ? AnyShapeStyle(DS.Color.positive) : AnyShapeStyle(.tertiary))

            Text(cycleStatusText)
                .font(.caption)
                .foregroundStyle((progress.isDue || progress.isOverdue) ? AnyShapeStyle(DS.Color.negative) : AnyShapeStyle(.secondary))

            if progress.isDue {
                Text("Due")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 1)
                    .background {
                        Capsule().fill(progress.isOverdue ? DS.Color.negative : progress.iconCategory.themeColor)
                    }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Duration/Value Type

    private func valueInput(unit: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView(
                value: Swift.min(progress.todayValue, progress.goalValue),
                total: progress.goalValue
            )
            .tint(progress.isCompleted ? DS.Color.positive : progress.iconCategory.themeColor)

            if isEditing {
                HStack(spacing: DS.Spacing.xs) {
                    TextField("0", text: $inputText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)

                    Button("Save") {
                        if let value = Double(inputText.trimmingCharacters(in: .whitespaces)), value > 0 {
                            onUpdateValue(value)
                            isEditing = false
                        }
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
            } else {
                Button {
                    inputText = progress.todayValue > 0 ? String(format: "%.0f", progress.todayValue) : ""
                    isEditing = true
                } label: {
                    Text("\(Int(progress.todayValue))/\(Int(progress.goalValue)) \(unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Count Type

    private var countInput: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView(
                value: Swift.min(progress.todayValue, progress.goalValue),
                total: progress.goalValue
            )
            .tint(progress.isCompleted ? DS.Color.positive : progress.iconCategory.themeColor)

            HStack(spacing: DS.Spacing.xs) {
                Button {
                    let newValue = Swift.max(0, progress.todayValue - 1)
                    onUpdateValue(newValue)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(progress.todayValue <= 0)

                Text("\(Int(progress.todayValue))/\(Int(progress.goalValue))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .frame(minWidth: 40)

                Button {
                    let newValue = progress.todayValue + 1
                    onUpdateValue(newValue)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(progress.iconCategory.themeColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cycleStatusText: String {
        if progress.isScheduled {
            if progress.cycleStartPoint == .firstCompletion, progress.cycleStartDate == nil {
                return String(localized: "Scheduled · Waiting for first completion")
            }
            if let startDate = progress.cycleStartDate {
                return String(localized: "Scheduled · Starts \(startDate.formatted(date: .abbreviated, time: .omitted))")
            }
            return String(localized: "Scheduled")
        }

        guard let nextDueDate = progress.nextDueDate else {
            return String(localized: "Tap to complete")
        }

        if progress.isOverdue {
            return String(localized: "Overdue · Tap to complete")
        }
        if progress.isDue {
            return String(localized: "Due today · Tap to complete")
        }

        let dueText = nextDueDate.formatted(date: .abbreviated, time: .omitted)
        switch progress.lastCycleAction {
        case .complete:
            return String(localized: "Done · Next \(dueText)")
        case .skip:
            return String(localized: "Skipped · Next \(dueText)")
        case .snooze:
            return String(localized: "Snoozed · Next \(dueText)")
        case .none:
            return String(localized: "Next due \(dueText)")
        }
    }

    @ViewBuilder
    private var cycleMetadata: some View {
        if progress.isScheduled {
            if let startDate = progress.cycleStartDate {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2)
                    Text("Starts \(startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            } else if progress.cycleStartPoint == .firstCompletion {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2)
                    Text("Starts on first completion")
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
        } else if let nextDueDate = progress.nextDueDate {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("Next due \(nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
    }
}
