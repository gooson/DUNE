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
                typeSection
                goalSection
                frequencySection
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
            .navigationTitle(isEdit ? String(localized: "Edit Habit") : String(localized: "New Habit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSaving)
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
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("habit-form-type")
        }
    }

    private var goalSection: some View {
        Section("Goal") {
            switch viewModel.selectedType {
            case .check:
                Text("Complete once per day")
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
                Text("Daily").tag("daily")
                Text("Weekly").tag("weekly")
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
            }
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
