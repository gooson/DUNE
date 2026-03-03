import SwiftUI

/// Reusable metric card with icon, value, and unit label.
/// Three sizes: `.large` for primary metrics, `.medium` for secondary, `.compact` for tertiary.
struct WorkoutMetricCard: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    let size: MetricSize

    enum MetricSize {
        case large
        case medium
        case compact
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(iconFont)
                .foregroundStyle(color)

            Text(value)
                .font(valueFont)
                .contentTransition(.numericText())

            Text(unit)
                .font(unitFont)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: size == .large ? .infinity : nil)
    }

    // MARK: - Size-Dependent Fonts

    private var iconFont: Font {
        switch size {
        case .large: .body
        case .medium: .caption
        case .compact: .caption2
        }
    }

    private var valueFont: Font {
        switch size {
        case .large: DS.Typography.primaryMetric
        case .medium: DS.Typography.secondaryMetric
        case .compact: DS.Typography.tileSubtitle.monospacedDigit()
        }
    }

    private var unitFont: Font {
        switch size {
        case .large: DS.Typography.metricLabel
        case .medium: DS.Typography.metricLabel
        case .compact: DS.Typography.tinyLabel
        }
    }
}
