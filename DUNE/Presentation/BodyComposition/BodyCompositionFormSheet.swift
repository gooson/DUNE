import SwiftUI

struct BodyCompositionFormSheet: View {
    @Bindable var viewModel: BodyCompositionViewModel
    let isEdit: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var saveCount = 0

    var body: some View {
        NavigationStack {
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
                .accessibilityIdentifier("body-date-picker")

                TextField("Weight (kg)", text: $viewModel.newWeight)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("body-weight-field")
                TextField("Body Fat (%)", text: $viewModel.newBodyFat)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("body-fat-field")
                TextField("Muscle Mass (kg)", text: $viewModel.newMuscleMass)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("body-muscle-field")
                TextField("Memo", text: $viewModel.newMemo)
            }
            .navigationTitle(isEdit ? "Edit Record" : "Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("body-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCount += 1
                        onSave()
                    }
                    .disabled(viewModel.newWeight.isEmpty && viewModel.newBodyFat.isEmpty && viewModel.newMuscleMass.isEmpty)
                    .accessibilityIdentifier("body-save-button")
                }
            }
        }
        .sensoryFeedback(.success, trigger: saveCount)
    }
}
