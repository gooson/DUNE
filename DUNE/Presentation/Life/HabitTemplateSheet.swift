import SwiftUI

struct HabitTemplateSheet: View {
    @Bindable var viewModel: LifeViewModel
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var contentWidth: CGFloat = 0

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
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                contentWidth = width
            }
            .accessibilityIdentifier("habit-template-list")
            .background { SheetWaveBackground() }
            .englishNavigationTitle("Habit Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("habit-template-cancel")
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

            let count = contentWidth >= 700 ? 4 : 2
            let columnCount = dynamicTypeSize.isAccessibilitySize ? count / 2 : count
            let columns = Array(
                repeating: GridItem(.flexible(), spacing: DS.Spacing.md),
                count: columnCount
            )
            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
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
            HabitTemplateCardLabel(
                template: template,
                frequency: frequencyDescription(template.suggestedFrequency),
                goal: goalDescription(template)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("habit-template-card-\(template.id)")
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


private struct HabitTemplateCardLabel: View {
    let template: HabitTemplate
    let frequency: String
    let goal: String

    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 38.0
    @ScaledMetric(relativeTo: .largeTitle) private var iconTileSize = 62.0

    private var tint: Color { template.iconCategory.themeColor(for: theme) }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    icon
                    Spacer(minLength: 0)
                    timeOfDay
                }
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    icon
                    timeOfDay
                }
            }

            Text(template.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DS.Spacing.xs)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    schedule
                    Spacer(minLength: 0)
                    goalValue
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    schedule
                    goalValue
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 208, alignment: .topLeading)
        .background {
            shape.fill(.thinMaterial)
            shape.fill(tint.opacity(0.08))
            Circle()
                .strokeBorder(tint.opacity(0.12), lineWidth: 22)
                .frame(width: 174, height: 174)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 82, y: 100)
                .allowsHitTesting(false)
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(tint.opacity(0.22), lineWidth: 1) }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        Image(systemName: template.iconCategory.iconName)
            .font(.system(size: Swift.min(iconSize, 52), weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: Swift.min(iconTileSize, 84), height: Swift.min(iconTileSize, 84))
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .accessibilityHidden(true)
    }

    private var timeOfDay: some View {
        Label(template.suggestedTimeOfDay.displayName, systemImage: template.suggestedTimeOfDay.iconName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var schedule: some View {
        Text(frequency)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var goalValue: some View {
        if template.type != .check {
            Text(goal)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
