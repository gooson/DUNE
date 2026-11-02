import SwiftUI

/// Shows notable highlights for a metric period (high, low, trend).
struct MetricHighlightsView: View {
    let highlights: [Highlight]
    let category: HealthMetric.Category
    let resolvedChartUnit: String?

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    init(highlights: [Highlight], category: HealthMetric.Category, resolvedChartUnit: String? = nil) {
        self.highlights = highlights
        self.category = category
        self.resolvedChartUnit = resolvedChartUnit
    }

    var body: some View {
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: isRegular ? DS.Spacing.md : DS.Spacing.sm) {
                Text("Highlights")
                    .font(isRegular ? .headline : .subheadline)
                    .fontWeight(.semibold)

                ForEach(highlights) { highlight in
                    InlineCard {
                        HStack(spacing: isRegular ? DS.Spacing.lg : DS.Spacing.md) {
                            Image(systemName: iconName(for: highlight.type))
                                .font(isRegular ? .body : .subheadline)
                                .foregroundStyle(iconColor(for: highlight.type))
                                .frame(width: isRegular ? 28 : 24)

                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(highlight.label)
                                    .font(isRegular ? .subheadline : .caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                Text(formattedValue(highlight))
                                    .font(isRegular ? .body : .subheadline)
                                    .fontWeight(.medium)
                                    .accessibilityIdentifier("metric-highlight-value-\(highlight.type.rawValue)")
                            }

                            Spacer()

                            Text(highlight.date, format: .dateTime.month(.abbreviated).day())
                                .font(isRegular ? .subheadline : .caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("metric-highlight-row-\(highlight.type.rawValue)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("metric-highlights")
        }
    }

    // MARK: - Helpers

    private func iconName(for type: Highlight.HighlightType) -> String {
        switch type {
        case .high:  "arrow.up.circle.fill"
        case .low:   "arrow.down.circle.fill"
        case .trend: "chart.line.uptrend.xyaxis"
        }
    }

    private func iconColor(for type: Highlight.HighlightType) -> Color {
        switch type {
        case .high:  DS.Color.positive
        case .low:   DS.Color.caution
        case .trend: category.themeColor
        }
    }

    private func formattedValue(_ highlight: Highlight) -> String {
        let value = highlight.value
        return switch category {
        case .hrv:               "\(value.formattedWithSeparator()) ms"
        case .rhr:               "\(value.formattedWithSeparator()) bpm"
        case .heartRate:         "\(value.formattedWithSeparator()) bpm"
        case .sleep:             value.hoursMinutesFormatted
        case .exercise: ExerciseHighlightValueFormatter.string(
            from: value, type: highlight.type, resolvedChartUnit: resolvedChartUnit
        )
        case .steps:             value.formattedWithSeparator()
        case .weight:            "\(value.formattedWithSeparator(fractionDigits: 1)) kg"
        case .bmi:               value.formattedWithSeparator(fractionDigits: 1)
        case .bodyFat:           "\(value.formattedWithSeparator(fractionDigits: 1))%"
        case .leanBodyMass:      "\(value.formattedWithSeparator(fractionDigits: 1)) kg"
        case .spo2:              "\((value * 100).formattedWithSeparator())%"
        case .respiratoryRate:   "\(value.formattedWithSeparator()) breaths/min"
        case .vo2Max:            "\(value.formattedWithSeparator(fractionDigits: 1)) ml/kg/min"
        case .heartRateRecovery: "\(value.formattedWithSeparator()) bpm"
        case .wristTemperature:  "\(value.formattedWithSeparator(fractionDigits: 1, alwaysShowSign: true)) °C"
        case .breathingDisturbances: "\(value.formattedWithSeparator(fractionDigits: 1))/hr"
        }
    }
}

/// Chart high/low values use the resolved exercise unit; a trend is already a percent change.
enum ExerciseHighlightValueFormatter {
    static func string(
        from value: Double,
        type: Highlight.HighlightType,
        resolvedChartUnit: String? = nil
    ) -> String {
        switch type {
        case .high, .low:
            if resolvedChartUnit == "km" {
                return "\(value.formattedWithSeparator(fractionDigits: 1)) km"
            }
            return "\(value.formattedWithSeparator()) min"
        case .trend:
            return "\(value.formattedWithSeparator(fractionDigits: 1))%"
        }
    }
}
