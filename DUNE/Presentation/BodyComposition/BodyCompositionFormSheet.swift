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
                .englishNavigationTitle(isEdit ? "Edit Record" : "Add Record")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focusedField = nil }
                            .accessibilityIdentifier("body-form-keyboard-done")
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("body-form-cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                if await onSave() {
                                    saveCount += 1
                                }
                            }
                        }
                        .disabled(viewModel.isSaving || (viewModel.newWeight.isEmpty && viewModel.newBodyFat.isEmpty && viewModel.newMuscleMass.isEmpty))
                        .accessibilityIdentifier("body-form-save")
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: saveCount)
        .background { SheetWaveBackground() }
    }
}
