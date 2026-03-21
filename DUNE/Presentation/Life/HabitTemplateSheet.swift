import SwiftUI

struct HabitTemplateSheet: View {
    @Bindable var viewModel: LifeViewModel
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.lg) {
                    ForEach(HabitTemplateCategory.allCases, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(DS.Spacing.md)
            }
            .background { SheetWaveBackground() }
            .englishNavigationTitle("Habit Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func categorySection(_ category: HabitTemplateCategory) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label(category.displayName, systemImage: category.iconName)
                .font(.headline)
                .foregroundStyle(DS.Color.tabLife)

            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(HabitTemplate.templates(for: category)) { template in
                    templateCard(template)
                }
            }
        }
    }

    private func templateCard(_ template: HabitTemplate) -> some View {
        Button {
            viewModel.prefillFromTemplate(template)
            dismiss()
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Image(systemName: template.iconCategory.iconName)
                        .font(.title3)
                        .foregroundStyle(template.iconCategory.themeColor)
                    Spacer()
                    Image(systemName: template.suggestedTimeOfDay.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(template.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(frequencyDescription(template.suggestedFrequency))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if template.type != .check {
                    Text(goalDescription(template))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(.ultraThinMaterial)
            }
        }
        .buttonStyle(.plain)
    }

    private func frequencyDescription(_ frequency: HabitFrequency) -> String {
        switch frequency {
        case .daily:
            return String(localized: "Every day")
        case .weekly(let days):
            return String(localized: "\(days)x per week")
        case .interval(let days):
            return String(localized: "Every \(days) days")
        }
    }

    private func goalDescription(_ template: HabitTemplate) -> String {
        switch template.type {
        case .check:
            return ""
        case .duration:
            return String(localized: "\(Int(template.suggestedGoalValue)) min")
        case .count:
            let unit = template.suggestedGoalUnit ?? ""
            return "\(Int(template.suggestedGoalValue)) \(unit)".trimmingCharacters(in: .whitespaces)
        }
    }
}
