import SwiftUI

/// Shows notable highlights for a metric period (high, low, trend).
struct MetricHighlightsView: View {
    let highlights: [Highlight]
    let category: HealthMetric.Category

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

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
                                Text(formattedValue(highlight.value))
                                    .font(isRegular ? .body : .subheadline)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            Text(highlight.date, format: .dateTime.month(.abbreviated).day())
                                .font(isRegular ? .subheadline : .caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
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

    private func formattedValue(_ value: Double) -> String {
        switch category {
        case .hrv:               "\(value.formattedWithSeparator()) ms"
        case .rhr:               "\(value.formattedWithSeparator()) bpm"
        case .heartRate:         "\(value.formattedWithSeparator()) bpm"
        case .sleep:             value.hoursMinutesFormatted
        case .exercise:          "\(value.formattedWithSeparator()) min"
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
        }
    }
}
