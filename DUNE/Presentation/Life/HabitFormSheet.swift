import SwiftUI

struct HabitFormSheet: View {
    @Bindable var viewModel: LifeViewModel
    let isEdit: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                iconSection
                typeSection
                goalSection
                frequencySection
                timeOfDaySection
                reminderTimeSection
                autoLinkSection

                if let error = viewModel.validationError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(DS.Color.negative)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { SheetWaveBackground() }
            .englishNavigationTitle(isEdit ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("habit-form-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("habit-form-save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("Habit name", text: $viewModel.name)
                .accessibilityIdentifier("habit-form-name")
        }
    }

    private var typeSection: some View {
        Section("Type") {
            Picker("Habit type", selection: $viewModel.selectedType) {
                ForEach(HabitType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                        .accessibilityIdentifier("habit-form-type-\(type.rawValue)")
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("habit-form-type")
        }
    }

    private var iconSection: some View {
        HabitIconPicker(selected: $viewModel.selectedIconCategory)
    }

    private var goalSection: some View {
        Section("Goal") {
            switch viewModel.selectedType {
            case .check:
                Text(viewModel.frequencyType == "interval" ? "Complete once per cycle" : "Complete once per day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .duration:
                HStack {
                    TextField("Minutes", text: $viewModel.goalValue)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("habit-form-goalvalue")
                    Text("min")
                        .foregroundStyle(.secondary)
                }
                TextField("Unit label (optional)", text: $viewModel.goalUnit)
                    .accessibilityIdentifier("habit-form-goalunit")
            case .count:
                HStack {
                    TextField("Count", text: $viewModel.goalValue)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("habit-form-goalvalue")
                    TextField("Unit (e.g. glasses)", text: $viewModel.goalUnit)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("habit-form-goalunit")
                }
            }
        }
    }

    private var frequencySection: some View {
        Section("Frequency") {
            Picker("Frequency", selection: $viewModel.frequencyType) {
                Text("Daily")
                    .tag("daily")
                    .accessibilityIdentifier("habit-form-frequency-daily")
                Text("Weekly")
                    .tag("weekly")
                    .accessibilityIdentifier("habit-form-frequency-weekly")
                Text("Recurring")
                    .tag("interval")
                    .accessibilityIdentifier("habit-form-frequency-interval")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("habit-form-frequency")

            if viewModel.frequencyType == "weekly" {
                Stepper(
                    "\(viewModel.weeklyTargetDays) days per week",
                    value: $viewModel.weeklyTargetDays,
                    in: 1...7
                )
                .accessibilityIdentifier("habit-weekly-stepper")
            } else if viewModel.frequencyType == "interval" {
                Stepper(
                    viewModel.intervalDays == 1 ? "Every day" : "Every \(viewModel.intervalDays) days",
                    value: $viewModel.intervalDays,
                    in: 1...365
                )
                .accessibilityIdentifier("habit-interval-stepper")

                Picker("Start point", selection: $viewModel.intervalStartPoint) {
                    ForEach(HabitRecurringStartPoint.allCases, id: \.self) { startPoint in
                        Text(startPoint.displayName)
                            .tag(startPoint)
                    }
                }
                .accessibilityIdentifier("habit-interval-start-point")

                if viewModel.intervalStartPoint == .customDate {
                    DatePicker(
                        "Start date",
                        selection: $viewModel.intervalCustomStartDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("habit-interval-start-date")
                }

                Text("Examples: 7 days (weekly), 30 days (monthly), 90 days (quarterly)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.intervalStartPoint == .firstCompletion {
                    Text("Schedule starts after the first completion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var timeOfDaySection: some View {
        Section("Time of Day") {
            Picker("When", selection: $viewModel.selectedTimeOfDay) {
                ForEach(HabitTimeOfDay.allCases, id: \.self) { time in
                    Label(time.displayName, systemImage: time.iconName)
                        .tag(time)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("habit-form-timeofday")
        }
    }

    @State private var reminderDate = Calendar.current.date(
        from: DateComponents(hour: 9, minute: 0)
    ) ?? Date()

    private var reminderTimeSection: some View {
        Section("Reminder") {
            DatePicker(
                "Reminder time",
                selection: Binding(
                    get: {
                        Calendar.current.date(
                            from: DateComponents(hour: viewModel.reminderHour, minute: viewModel.reminderMinute)
                        ) ?? Date()
                    },
                    set: { newDate in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        viewModel.reminderHour = components.hour ?? 9
                        viewModel.reminderMinute = components.minute ?? 0
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .accessibilityIdentifier("habit-form-reminder-time")

            Text("You'll receive reminders based on the habit's frequency")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var autoLinkSection: some View {
        Section {
            Toggle("Auto-complete from workouts", isOn: $viewModel.isAutoLinked)
                .accessibilityIdentifier("habit-auto-link-toggle")

            if viewModel.isAutoLinked {
                Text("Automatically marks as done when you log a workout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Auto Link")
        }
    }
}

// MARK: - Icon Picker Section

struct HabitIconPicker: View {
    @Binding var selected: HabitIconCategory
    private let columns = Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: 4)

    var body: some View {
        Section("Icon") {
            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(HabitIconCategory.allCases, id: \.self) { category in
                    Button {
                        selected = category
                    } label: {
                        VStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: category.iconName)
                                .font(.title3)
                            Text(category.displayName)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .fill(selected == category ? category.themeColor.opacity(DS.Opacity.medium) : .clear)
                        }
                        .overlay {
                            if selected == category {
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .stroke(category.themeColor, lineWidth: 1.5)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selected == category ? category.themeColor : .secondary)
                }
            }
        }
    }
}
