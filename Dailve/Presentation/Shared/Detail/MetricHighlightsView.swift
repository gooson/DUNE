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
                                    .foregroundStyle(.secondary)
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
        case .hrv:               String(format: "%.0f ms", value)
        case .rhr:               String(format: "%.0f bpm", value)
        case .heartRate:         String(format: "%.0f bpm", value)
        case .sleep:             value.hoursMinutesFormatted
        case .exercise:          String(format: "%.0f min", value)
        case .steps:             String(format: "%.0f", value)
        case .weight:            String(format: "%.1f kg", value)
        case .bmi:               String(format: "%.1f", value)
        case .bodyFat:           String(format: "%.1f%%", value)
        case .leanBodyMass:      String(format: "%.1f kg", value)
        case .spo2:              String(format: "%.0f%%", value * 100)
        case .respiratoryRate:   String(format: "%.0f breaths/min", value)
        case .vo2Max:            String(format: "%.1f ml/kg/min", value)
        case .heartRateRecovery: String(format: "%.0f bpm", value)
        case .wristTemperature:  String(format: "%+.1f °C", value)
        }
    }
}
