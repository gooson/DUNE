import SwiftUI

struct PinnedMetricsEditorView: View {
    @Binding var selection: [HealthMetric.Category]
    let allowedCategories: [HealthMetric.Category]

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var workingSelection: [HealthMetric.Category] = []

    private var selectedSet: Set<HealthMetric.Category> {
        Set(workingSelection)
    }

    private var iconTint: Color {
        colorScheme == .light ? theme.accentColor.mix(with: .black, by: 0.45) : theme.accentColor
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    selectionHero
                        .listRowInsets(EdgeInsets(top: DS.Spacing.sm, leading: DS.Spacing.lg, bottom: DS.Spacing.sm, trailing: DS.Spacing.lg))
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(allowedCategories, id: \.rawValue) { category in
                        Button {
                            toggle(category)
                        } label: {
                            HStack(alignment: .center, spacing: DS.Spacing.md) {
                                Image(systemName: category.iconName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(colorScheme == .light
                                        ? category.themeColor.mix(with: .black, by: 0.35)
                                        : category.themeColor)
                                    .frame(minWidth: 36, minHeight: 36)
                                    .background(category.themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                                    .accessibilityHidden(true)

                                Text(category.displayName)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if selectedSet.contains(category) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DS.Color.positive)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedSet.contains(category) ? .isSelected : [])
                        .accessibilityIdentifier("pinned-metrics-editor-row-\(category.rawValue)")
                        .disabled(!selectedSet.contains(category) && workingSelection.count >= TodayPinnedMetricsStore.maxPinnedCount)
                    }
                } footer: {
                    Text("Select up to \(TodayPinnedMetricsStore.maxPinnedCount) metrics shown at the top of Today.")
                        .accessibilityIdentifier("pinned-metrics-editor-footer")
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

    private var selectionHero: some View {
        HeroCard(tintColor: iconTint) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Label {
                    Text("Top \(TodayPinnedMetricsStore.maxPinnedCount) Metrics")
                        .accessibilityIdentifier("pinned-metrics-editor-title")
                } icon: {
                    Image(systemName: "pin.fill")
                        .accessibilityHidden(true)
                }
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [GridItem(.adaptive(
                        minimum: dynamicTypeSize.isAccessibilitySize ? 80 : 36,
                        maximum: dynamicTypeSize.isAccessibilitySize ? 120 : 44
                    ), spacing: DS.Spacing.sm)],
                    alignment: .leading,
                    spacing: DS.Spacing.sm
                ) {
                    ForEach(workingSelection.indices, id: \.self) { index in
                        Image(systemName: workingSelection[index].iconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(iconTint)
                            .frame(minWidth: 36, minHeight: 36)
                            .background(iconTint.opacity(0.12), in: Circle())
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
