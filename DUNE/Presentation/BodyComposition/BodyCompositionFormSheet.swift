import SwiftUI

struct BodyCompositionFormSheet: View {
    @Bindable var viewModel: BodyCompositionViewModel
    let isEdit: Bool
    let onSave: @MainActor () async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var saveCount = 0

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

                    TextField("Weight (kg)", text: $viewModel.newWeight)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("body-form-weight")
                    TextField("Body Fat (%)", text: $viewModel.newBodyFat)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("body-form-fat")
                    TextField("Muscle Mass (kg)", text: $viewModel.newMuscleMass)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("body-form-muscle")
                    TextField("Memo", text: $viewModel.newMemo)
                }
                .scrollContentBackground(.hidden)
                .englishNavigationTitle(isEdit ? "Edit Record" : "Add Record")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
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
