import SwiftUI

struct HabitPastRecordSheet: View {
    let habits: [HabitDefinition]
    let onSave: (HabitDefinition, Date, Double) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedHabitID: UUID?
    @State private var selectedDate: Date
    @State private var totalInput = ""
    @State private var isCompleted = true
    @State private var validationError: String?
    @State private var isSaving = false
    @State private var previewViewModel = LifeViewModel()

    init(
        habits: [HabitDefinition],
        selectedHabit: HabitDefinition? = nil,
        selectedDate: Date? = nil,
        onSave: @escaping (HabitDefinition, Date, Double) -> Bool
    ) {
        self.habits = habits
        self.onSave = onSave
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        _selectedHabitID = State(initialValue: selectedHabit?.id ?? habits.first(where: Self.isEligible)?.id)
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: selectedDate ?? yesterday))
    }

    var body: some View {
        NavigationStack {
            Form {
                if eligibleHabits.isEmpty {
                    ContentUnavailableView(
                        "No habits to record",
                        systemImage: "checklist",
                        description: Text("Add a manual habit to record a past day.")
                    )
                } else {
                    habitSection
                    dateSection
                    totalSection
                    impactSection
                    if let validationError {
                        Section {
                            Text(validationError)
                                .font(.caption)
                                .foregroundStyle(DS.Color.negative)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { SheetWaveBackground() }
            .navigationTitle("Past Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("habit-past-record-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(selectedHabit == nil || isSaving || !hasAvailableDates)
                        .accessibilityIdentifier("habit-past-record-save")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { updateSelection() }
        .onChange(of: selectedHabitID) { _, _ in updateSelection() }
        .onChange(of: selectedDate) { _, _ in updateInput() }
    }

    private var eligibleHabits: [HabitDefinition] {
        habits.filter(Self.isEligible)
    }

    private var selectedHabit: HabitDefinition? {
        eligibleHabits.first { $0.id == selectedHabitID }
    }

    private var latestDate: Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
    }

    private var earliestDate: Date? {
        guard let selectedHabit else { return nil }
        let calendar = Calendar.current
        let created = calendar.startOfDay(for: selectedHabit.createdAt)
        guard selectedHabit.frequency.intervalDays != nil else { return created }
        let configured = calendar.startOfDay(
            for: selectedHabit.recurringStartConfiguredAt ?? selectedHabit.createdAt
        )
        return max(created, configured)
    }

    private var hasAvailableDates: Bool {
        earliestDate.map { $0 <= latestDate } ?? false
    }

    private var existingLogs: [HabitLog] {
        guard let selectedHabit else { return [] }
        let calendar = Calendar.current
        return (selectedHabit.logs ?? []).filter {
            !$0.isAutoCompleted && calendar.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

    private var existingTotal: Double {
        existingLogs.reduce(0) { $0 + $1.value }
    }

    private var enteredValue: Double? {
        guard let selectedHabit else { return nil }
        if selectedHabit.habitType == .check { return isCompleted ? 1 : 0 }
        let trimmed = totalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    private var previewNextDueDate: Date? {
        guard let selectedHabit, let enteredValue else { return nil }
        return previewViewModel.previewPastRecordNextDueDate(
            for: selectedHabit,
            value: enteredValue,
            date: selectedDate
        )
    }

    private var habitSection: some View {
        Section("Habit") {
            Picker("Habit", selection: $selectedHabitID) {
                ForEach(eligibleHabits, id: \.id) { habit in
                    Text(habit.name).tag(Optional(habit.id))
                }
            }
            .accessibilityIdentifier("habit-past-record-habit")
        }
    }

    @ViewBuilder
    private var dateSection: some View {
        if let earliestDate, hasAvailableDates {
            Section("Record Date") {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: earliestDate...latestDate,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("habit-past-record-date")
            }
        } else {
            Section("Record Date") {
                Text("This habit has no past dates available yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var totalSection: some View {
        if let selectedHabit, hasAvailableDates {
            Section("Total for the day") {
                if !existingLogs.isEmpty {
                    LabeledContent("Current total") {
                        Text(existingTotal, format: .number.precision(.fractionLength(0...2)).grouping(.never))
                    }
                    Text("Saving replaces this date's recorded total.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                switch selectedHabit.habitType {
                case .check:
                    Toggle("Completed", isOn: $isCompleted)
                        .accessibilityIdentifier("habit-past-record-completed")
                case .count, .duration:
                    HStack {
                        TextField("Total", text: $totalInput)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("habit-past-record-total")
                        if selectedHabit.habitType == .duration {
                            Text("min").foregroundStyle(.secondary)
                        } else if let unit = selectedHabit.goalUnit, !unit.isEmpty {
                            Text(unit).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Enter 0 to clear this date's manual record.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var impactSection: some View {
        Section {
            Text("Past records update history and progress for that date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if selectedHabit?.frequency.intervalDays != nil {
                if let previewNextDueDate {
                    LabeledContent("Next scheduled date") {
                        Text(previewNextDueDate, format: .dateTime.year().month().day())
                    }
                } else {
                    Text("Enter a valid total to preview the next scheduled date.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static func isEligible(_ habit: HabitDefinition) -> Bool {
        !habit.isArchived && !habit.isAutoLinked
    }

    private func updateSelection() {
        guard let earliestDate else { return }
        if selectedDate < earliestDate { selectedDate = earliestDate }
        if selectedDate > latestDate { selectedDate = latestDate }
        updateInput()
    }

    private func updateInput() {
        validationError = nil
        if selectedHabit?.habitType == .check {
            isCompleted = existingLogs.isEmpty || existingTotal > 0
        } else {
            totalInput = existingTotal == 0
                ? ""
                : existingTotal.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
        }
    }

    private func save() {
        guard !isSaving, let selectedHabit, hasAvailableDates else { return }
        validationError = nil

        let value: Double
        switch selectedHabit.habitType {
        case .check:
            value = isCompleted ? 1 : 0
        case .count, .duration:
            guard let parsed = enteredValue else {
                validationError = String(localized: "Enter a valid total")
                return
            }
            let maximum = selectedHabit.habitType == .duration ? 1440.0 : 999.0
            guard parsed >= 0, parsed <= maximum else {
                validationError = selectedHabit.habitType == .duration
                    ? String(localized: "Duration must be between 0 and 1440 minutes")
                    : String(localized: "Count must be between 0 and 999")
                return
            }
            value = parsed
        }

        isSaving = true
        if onSave(selectedHabit, selectedDate, value) {
            dismiss()
        } else {
            isSaving = false
            validationError = String(localized: "Could not save this record")
        }
    }
}

#Preview {
    HabitPastRecordSheet(habits: []) { _, _, _ in false }
}
