import SwiftUI

struct PinnedMetricsEditorView: View {
    @Binding var selection: [HealthMetric.Category]
    let allowedCategories: [HealthMetric.Category]

    @Environment(\.dismiss) private var dismiss
    @State private var workingSelection: [HealthMetric.Category] = []

    private var selectedSet: Set<HealthMetric.Category> {
        Set(workingSelection)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(allowedCategories, id: \.rawValue) { category in
                        Button {
                            toggle(category)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: category.iconName)
                                    .foregroundStyle(category.themeColor)
                                Text(category.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSet.contains(category) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DS.Color.positive)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!selectedSet.contains(category) && workingSelection.count >= 3)
                    }
                } header: {
                    Text("Top 3 Metrics")
                } footer: {
                    Text("Select up to 3 metrics shown at the top of Today.")
                }
            }
            .navigationTitle("Edit Pinned Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selection = workingSelection
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            workingSelection = selection
        }
    }

    private func toggle(_ category: HealthMetric.Category) {
        if let index = workingSelection.firstIndex(of: category) {
            workingSelection.remove(at: index)
            return
        }
        guard workingSelection.count < 3 else { return }
        workingSelection.append(category)
    }
}
