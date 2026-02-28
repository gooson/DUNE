import SwiftUI

struct InjuryFormSheet: View {
    @Bindable var viewModel: InjuryViewModel
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

                Section("Body Part") {
                    Picker("Location", selection: $viewModel.selectedBodyPart) {
                        Section("Joints") {
                            ForEach(BodyPart.allCases.filter(\.isJoint), id: \.self) { part in
                                Text(part.bilingualDisplayName).tag(part)
                            }
                        }
                        Section("Muscles") {
                            ForEach(BodyPart.allCases.filter { !$0.isJoint }, id: \.self) { part in
                                Text(part.bilingualDisplayName).tag(part)
                            }
                        }
                    }
                    .accessibilityIdentifier("injury-bodypart-picker")

                    if viewModel.selectedBodyPart.isLateral {
                        Picker("Side", selection: Binding(
                            get: { viewModel.selectedSide ?? .both },
                            set: { viewModel.selectedSide = $0 }
                        )) {
                            ForEach(BodySide.allCases, id: \.self) { side in
                                Text(side.bilingualDisplayName).tag(side)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("injury-side-picker")
                    }
                }

                Section("Severity") {
                    ForEach(InjurySeverity.allCases, id: \.self) { severity in
                        Button {
                            viewModel.selectedSeverity = severity
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: severity.iconName)
                                    .font(.title3)
                                    .foregroundStyle(severity.color)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(severity.bilingualDisplayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(DS.Color.sandMuted)
                                    Text(severity.localizedSeverityDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if viewModel.selectedSeverity == severity {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(severity.color)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("injury-severity-\(severity.displayName.lowercased())")
                    }
                }

                Section("Duration") {
                    DatePicker(
                        "Start Date",
                        selection: $viewModel.startDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .accessibilityIdentifier("injury-start-date")

                    Toggle("Recovered", isOn: Binding(
                        get: { viewModel.endDate != nil },
                        set: { isRecovered in
                            viewModel.endDate = isRecovered ? Date() : nil
                        }
                    ))

                    if viewModel.endDate != nil {
                        DatePicker(
                            "End Date",
                            selection: Binding(
                                get: { viewModel.endDate ?? Date() },
                                set: { viewModel.endDate = $0 }
                            ),
                            in: viewModel.startDate...Date(),
                            displayedComponents: [.date]
                        )
                        .accessibilityIdentifier("injury-end-date")
                    }
                }

                Section("Notes") {
                    TextField("Memo (optional)", text: $viewModel.memo, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("injury-memo-field")
                }
            }
            .scrollContentBackground(.hidden)
            .background { SheetWaveBackground() }
            .navigationTitle(isEdit ? "Edit Injury" : "Add Injury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("injury-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let hadError = viewModel.validationError != nil
                        onSave()
                        // Only trigger success haptic if validation passed
                        if !hadError, viewModel.validationError == nil {
                            saveCount += 1
                        }
                    }
                    .accessibilityIdentifier("injury-save-button")
                }
            }
        }
        .sensoryFeedback(.success, trigger: saveCount)
    }
}
