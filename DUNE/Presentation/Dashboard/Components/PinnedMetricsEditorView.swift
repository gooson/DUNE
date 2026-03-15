import SwiftUI

struct PinnedMetricsEditorView: View {
    @Binding var selection: [HealthMetric.Category]
    let allowedCategories: [HealthMetric.Category]

    @Environment(\.appTheme) private var theme
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
                                    .foregroundStyle(theme.sandColor)
                                Spacer()
                                if selectedSet.contains(category) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DS.Color.positive)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!selectedSet.contains(category) && workingSelection.count >= TodayPinnedMetricsStore.maxPinnedCount)
                    }
                } header: {
                    Text("Top \(TodayPinnedMetricsStore.maxPinnedCount) Metrics")
                } footer: {
                    Text("Select up to \(TodayPinnedMetricsStore.maxPinnedCount) metrics shown at the top of Today.")
                }
            }
            .scrollContentBackground(.hidden)
            .background { SheetWaveBackground() }
            .englishNavigationTitle("Edit Pinned Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("pinned-metrics-editor-screen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("pinned-metrics-editor-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selection = workingSelection
                        dismiss()
                    }
                    .accessibilityIdentifier("pinned-metrics-editor-done")
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
        guard workingSelection.count < TodayPinnedMetricsStore.maxPinnedCount else { return }
        workingSelection.append(category)
    }
}
