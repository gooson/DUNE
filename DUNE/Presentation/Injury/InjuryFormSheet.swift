import SwiftUI

struct InjuryFormSheet: View {
    @Bindable var viewModel: InjuryViewModel
    let isEdit: Bool
    let onSave: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .title3) private var severityIconWidth: CGFloat = 28
    @State private var saveCount = 0

    private var formTint: Color {
        colorScheme == .light ? theme.accentColor.mix(with: .black, by: 0.45) : theme.accentColor
    }

    private func severityForeground(_ severity: InjurySeverity) -> Color {
        colorScheme == .light ? severity.color.mix(with: .black, by: 0.45) : severity.color
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("injury-form-screen")

                Form {
                    if let error = viewModel.validationError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Section {
                        Picker("Location", selection: $viewModel.selectedBodyPart) {
                            Section("Joints") {
                                ForEach(BodyPart.allCases.filter(\.isJoint), id: \.self) { part in
                                    Text(part.displayName).tag(part)
                                }
                            }
                            Section("Muscles") {
                                ForEach(BodyPart.allCases.filter { !$0.isJoint }, id: \.self) { part in
                                    Text(part.displayName).tag(part)
                                }
                            }
                        }
                        .accessibilityIdentifier("injury-form-bodypart")

                        if viewModel.selectedBodyPart.isLateral {
                            Picker("Side", selection: Binding(
                                get: { viewModel.selectedSide ?? .both },
                                set: { viewModel.selectedSide = $0 }
                            )) {
                                ForEach(BodySide.allCases, id: \.self) { side in
                                    Text(side.displayName).tag(side)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("injury-form-side")
                        }
                    } header: {
                        Label("Body Part", systemImage: viewModel.selectedBodyPart.iconName)
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Section {
                        ForEach(InjurySeverity.allCases, id: \.self) { severity in
                            Button {
                                viewModel.selectedSeverity = severity
                            } label: {
                                HStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: severity.iconName)
                                        .font(.title3)
                                        .foregroundStyle(severityForeground(severity))
                                        .frame(width: severityIconWidth)

                                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                        Text(severity.displayName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text(severity.severityDescription)
                                            .font(.caption)
                                            .foregroundStyle(DS.Color.textSecondary)
                                    }

                                    Spacer()

                                    if viewModel.selectedSeverity == severity {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(severityForeground(severity))
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("injury-form-severity-\(severity.displayName.lowercased())")
                        }
                    } header: {
                        Label("Severity", systemImage: "bandage.fill")
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Section {
                        DatePicker(
                            "Start Date",
                            selection: $viewModel.startDate,
                            in: ...Date(),
                            displayedComponents: [.date]
                        )
                        .accessibilityIdentifier("injury-form-startdate")

                        Button {
                            viewModel.isRecovered.toggle()
                            viewModel.endDate = viewModel.isRecovered ? (viewModel.endDate ?? Date()) : nil
                        } label: {
                            HStack {
                                Text("Recovered")
                                Spacer()
                                Image(systemName: viewModel.isRecovered ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.isRecovered ? Color.green : DS.Color.textSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("injury-form-recovered-toggle")
                        .accessibilityValue(viewModel.isRecovered ? "On" : "Off")

                        if viewModel.isRecovered, viewModel.endDate != nil {
                            DatePicker(
                                selection: Binding(
                                    get: { viewModel.endDate ?? Date() },
                                    set: { viewModel.endDate = $0 }
                                ),
                                in: viewModel.startDate...Date(),
                                displayedComponents: [.date]
                            ) {
                                Text("End Date")
                                    .accessibilityIdentifier("injury-form-enddate")
                            }
                        }
                    } header: {
                        Label("Duration", systemImage: "calendar")
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Section {
                        TextField("Memo (optional)", text: $viewModel.memo, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("injury-form-memo")
                    } header: {
                        Label("Notes", systemImage: "note.text")
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .background { SheetWaveBackground() }
                .englishNavigationTitle(isEdit ? "Edit Injury" : "Add Injury")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("injury-form-cancel")
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
                        .disabled(viewModel.isSaving)
                        .accessibilityIdentifier("injury-form-save")
                    }
                }
            }
        }
        .tint(formTint)
        .sensoryFeedback(.success, trigger: saveCount)
    }
}
