import SwiftUI

/// Apple Fitness-style effort slider (1-10) with auto-suggestion and history context.
struct EffortSliderView: View {
    @Binding var effort: Int?
    let suggestion: EffortSuggestion?

    @State private var sliderValue: Double = 5
    @State private var didInitialize = false

    private var currentEffort: Int { effort ?? suggestion?.suggestedEffort ?? 5 }
    private var currentCategory: EffortCategory { EffortCategory(effort: currentEffort) }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Header
            Text("How did it feel?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DS.Color.textSecondary)

            // Big number + category
            effortDisplay

            // Slider
            effortSlider

            // Category labels
            categoryLabels

            // History context
            if let suggestion, suggestion.lastEffort != nil || suggestion.averageEffort != nil {
                historyContext(suggestion)
            }
        }
    }

    // MARK: - Effort Display

    private var effortDisplay: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: currentCategory.iconName)
                    .font(.title2)
                    .foregroundStyle(currentCategory.color)

                Text("\(currentEffort)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(currentCategory.color)
                    .contentTransition(.numericText())

                Text("/ 10")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Text(currentCategory.displayName)
                .font(.headline)
                .foregroundStyle(currentCategory.color)
                .contentTransition(.interpolate)
        }
        .animation(DS.Animation.snappy, value: currentEffort)
    }

    // MARK: - Slider

    private var effortSlider: some View {
        VStack(spacing: DS.Spacing.xs) {
            Slider(
                value: $sliderValue,
                in: 1...10,
                step: 1
            ) {
                Text("Effort")
            } minimumValueLabel: {
                Text("1")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(DS.Color.textSecondary)
            } maximumValueLabel: {
                Text("10")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .tint(currentCategory.color)
            .sensoryFeedback(.selection, trigger: Int(sliderValue))
            .onChange(of: sliderValue) { _, newValue in
                effort = Int(round(newValue))
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .task {
            guard !didInitialize, let suggestion else { return }
            sliderValue = Double(suggestion.suggestedEffort)
            effort = suggestion.suggestedEffort
            didInitialize = true
        }
    }

    // MARK: - Category Labels

    private var categoryLabels: some View {
        HStack {
            ForEach(EffortCategory.allCases, id: \.rawValue) { category in
                Text(category.displayName)
                    .font(.caption2)
                    .foregroundStyle(currentCategory == category ? category.color : DS.Color.textSecondary)
                    .fontWeight(currentCategory == category ? .semibold : .regular)
                if category != .allOut {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    // MARK: - History Context

    private func historyContext(_ suggestion: EffortSuggestion) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            if let last = suggestion.lastEffort {
                contextItem(label: "Last time", value: "\(last)")
            }
            if let avg = suggestion.averageEffort {
                contextItem(label: "Average", value: avg.formattedWithSeparator(fractionDigits: 1))
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func contextItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}
