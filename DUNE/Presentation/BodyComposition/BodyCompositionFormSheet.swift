import SwiftUI

struct BodyCompositionFormSheet: View {
    @Bindable var viewModel: BodyCompositionViewModel
    let isEdit: Bool
    let onSave: @MainActor () async -> Bool
    @Environment(\.dismiss) private var dismiss
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

                    Section("Weight (kg)") {
                        TextField("Weight (kg)", text: $viewModel.newWeight)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .weight)
                            .accessibilityIdentifier("body-form-weight")
                    }
                    Section("Body Fat (%)") {
                        TextField("Body Fat (%)", text: $viewModel.newBodyFat)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .bodyFat)
                            .accessibilityIdentifier("body-form-fat")
                    }
                    Section("Muscle Mass (kg)") {
                        TextField("Muscle Mass (kg)", text: $viewModel.newMuscleMass)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .muscleMass)
                            .accessibilityIdentifier("body-form-muscle")
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
                    Button("Save") {
                        focusedField = nil
                        Task {
                            if await onSave() {
                                saveCount += 1
                            }
                        }
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
}
