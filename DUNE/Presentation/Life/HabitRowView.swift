import SwiftUI

struct HabitRowView: View {
    let progress: HabitProgress
    let onToggle: () -> Void
    let onUpdateValue: (Double) -> Void
    let onValidateValue: ((Double) -> Bool)?
    let trailingAccessory: AnyView?

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var inputText = ""
    @State private var isEditing = false

    init(progress: HabitProgress, onToggle: @escaping () -> Void, onUpdateValue: @escaping (Double) -> Void, trailingAccessory: AnyView? = nil, onValidateValue: ((Double) -> Bool)? = nil) {
        self.progress = progress
        self.onToggle = onToggle
        self.onUpdateValue = onUpdateValue
        self.onValidateValue = onValidateValue
        self.trailingAccessory = trailingAccessory
    }

    private var tint: Color { progress.iconCategory.themeColor(for: theme) }
    private var value: Double { max(0, progress.todayValue) }
    private var goal: Double { max(0, progress.goalValue) }
    private var toggleDisabled: Bool {
        progress.isAutoLinked || progress.isAutoCompleted || (progress.isCycleBased && !progress.isCompleted && !progress.canCompleteCycle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: progress.iconCategory.iconName)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(DS.Opacity.medium), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(progress.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("life-habit-row-\(progress.name)")
                    if progress.isCycleBased {
                        Text(cycleStatusText)
                            .font(.caption)
                            .foregroundStyle(progress.isOverdue ? DS.Color.negative : theme.secondaryTextColor)
                    } else if case .weekly(let days) = progress.frequency {
                        Text("Weekly goal: \(days) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if progress.isAutoLinked {
                        Text("Auto")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let trailingAccessory {
                    trailingAccessory.frame(minWidth: 44, minHeight: 44)
                }
            }
            inputContent
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(theme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .fill(tint.opacity(DS.Opacity.subtle))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(tint.opacity(DS.Opacity.border), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var inputContent: some View {
        if progress.isCycleBased || progress.isAutoLinked || progress.type == .check {
            checkInput
        } else {
            switch progress.type {
            case .check: checkInput
            case .duration: durationInput
            case .count: countInput
            }
        }
    }

    private var checkInput: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: onToggle) {
                Label(progress.isCompleted ? "Undo" : "Complete", systemImage: progress.isCompleted ? "arrow.uturn.backward" : "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 96, minHeight: 44)
                    .padding(.horizontal, DS.Spacing.sm)
                    .background(progress.isCompleted ? tint.opacity(DS.Opacity.medium) : tint, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .foregroundStyle(progress.isCompleted ? tint : DS.Color.onBrightAction)
            }
            .buttonStyle(.plain)
            .disabled(toggleDisabled)
            .accessibilityLabel(progress.isCompleted ? Text("Undo \(progress.name)") : Text("Complete \(progress.name)"))
        }
    }

    private var durationInput: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if isEditing {
                let editorLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
                    : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
                editorLayout {
                    TextField("0", text: $inputText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                    Button("Save") {
                        let decimalSeparator = Locale.current.decimalSeparator ?? "."
                        let normalized = inputText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: decimalSeparator, with: ".")
                        if let newValue = Double(normalized), newValue >= 0, onValidateValue?(newValue) ?? true {
                            onUpdateValue(newValue)
                            isEditing = false
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(value.formatted())
                        .accessibilityIdentifier("life-habit-value-\(progress.name)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text(verbatim: "/ \(goal.formatted()) \(progress.goalUnit ?? String(localized: "min"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Edit time") {
                        inputText = value.formatted(.number.grouping(.never))
                        isEditing = true
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
                    .disabled(progress.isAutoLinked)
                }
            }
            meter
        }
    }

    private var countInput: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
            layout {
                Button { onUpdateValue(max(0, value - 1)) } label: {
                    Image(systemName: "minus")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(tint.opacity(DS.Opacity.medium), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(value <= 0)
                .accessibilityLabel(Text("Decrease \(progress.name)"))
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(value.formatted())
                        .accessibilityIdentifier("life-habit-value-\(progress.name)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(tint)
                    Text(verbatim: "/ \(goal.formatted()) \(progress.goalUnit ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
                Button { onUpdateValue(value + 1) } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(tint.opacity(DS.Opacity.medium), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Increase \(progress.name)"))
            }
            if progress.iconCategory == .hydration, goal > 0, goal <= 12 {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<Int(goal.rounded(.up)), id: \.self) { index in
                        Image(systemName: index < Int(value) ? "drop.fill" : "drop")
                            .font(.caption)
                            .foregroundStyle(index < Int(value) ? tint : tint.opacity(0.35))
                    }
                }
                .accessibilityHidden(true)
            } else {
                meter
            }
        }
    }

    private var meter: some View {
        ProgressView(value: min(value, goal), total: max(goal, 1))
            .tint(tint)
            .accessibilityLabel(Text("\(progress.name) progress"))
    }

    private var cycleStatusText: String {
        if progress.isScheduled {
            if progress.cycleStartPoint == .firstCompletion, progress.cycleStartDate == nil {
                return String(localized: "Waiting for first completion")
            }
            if let startDate = progress.cycleStartDate {
                return String(localized: "Starts \(startDate.formatted(date: .abbreviated, time: .omitted))")
            }
            return String(localized: "Scheduled")
        }
        guard let dueDate = progress.nextDueDate else { return String(localized: "Due today") }
        if progress.isOverdue { return String(localized: "Overdue") }
        if progress.isDue { return String(localized: "Due today") }
        return String(localized: "Next due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
    }
}
