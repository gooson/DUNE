import SwiftUI

struct BodyCompositionFormSheet: View {
    @Bindable var viewModel: BodyCompositionViewModel
    let isEdit: Bool
    let onSave: @MainActor () async -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var saveCount = 0
    @FocusState private var focusedField: InputField?

    private enum InputField: Hashable {
        case weight, bodyFat, muscleMass, memo

        var identifier: String {
            switch self {
            case .weight: "body-form-weight"
            case .bodyFat: "body-form-fat"
            case .muscleMass: "body-form-muscle"
            case .memo: "body-form-memo"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("body-form-screen")

                Form {
                    if let error = viewModel.validationError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    DatePicker(
                        "Date & Time",
                        selection: $viewModel.selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("body-form-date")

                    Section {
                        TextField("Weight (kg)", text: $viewModel.newWeight)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .weight)
                            .accessibilityIdentifier("body-form-weight")
                    } header: {
                        measurementHeader("Weight (kg)", category: .weight)
                    }
                    Section {
                        TextField("Body Fat (%)", text: $viewModel.newBodyFat)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .bodyFat)
                            .accessibilityIdentifier("body-form-fat")
                    } header: {
                        measurementHeader("Body Fat (%)", category: .bodyFat)
                    }
                    Section {
                        TextField("Muscle Mass (kg)", text: $viewModel.newMuscleMass)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .muscleMass)
                            .accessibilityIdentifier("body-form-muscle")
                    } header: {
                        measurementHeader("Muscle Mass (kg)", category: .leanBodyMass)
                    }
                    TextField("Memo", text: $viewModel.newMemo)
                        .focused($focusedField, equals: .memo)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if let field = focusedField {
                            Button("Clear Input") {
                                switch field {
                                case .weight: viewModel.newWeight = ""
                                case .bodyFat: viewModel.newBodyFat = ""
                                case .muscleMass: viewModel.newMuscleMass = ""
                                case .memo: viewModel.newMemo = ""
                                }
                            }
                            .accessibilityIdentifier("\(field.identifier)-clear")
                        }
                        Spacer()
                        Button("Done") { focusedField = nil }
                            .accessibilityIdentifier("body-form-keyboard-done")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("body-form-cancel")
                    Spacer()
                    Button {
                        focusedField = nil
                        Task {
                            if await onSave() {
                                saveCount += 1
                            }
                        }
                    } label: {
                        Text("Save")
                            .foregroundStyle(theme.prominentButtonForegroundColor(for: colorScheme))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving || (viewModel.newWeight.isEmpty && viewModel.newBodyFat.isEmpty && viewModel.newMuscleMass.isEmpty))
                    .accessibilityIdentifier("body-form-save")
                }
                .padding(DS.Spacing.md)
                .background(.bar)
            }
            .englishNavigationTitle(isEdit ? "Edit Record" : "Add Record")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sensoryFeedback(.success, trigger: saveCount)
        .background { SheetWaveBackground() }
    }

    private func measurementHeader(_ title: LocalizedStringKey, category: HealthMetric.Category) -> some View {
        Label {
            Text(title)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: category.iconName)
                .foregroundStyle(category.themeColor)
                .accessibilityHidden(true)
        }
    }
}
