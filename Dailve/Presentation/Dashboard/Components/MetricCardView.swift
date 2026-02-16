import SwiftUI

struct MetricCardView: View {
    let metric: HealthMetric

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }
    private var cardPadding: CGFloat { isRegular ? DS.Spacing.xxl : DS.Spacing.lg }
    private var valueFont: Font { isRegular ? .title : .title2 }
    private var headerFont: Font { isRegular ? .subheadline : .caption }
    private var cardSpacing: CGFloat { isRegular ? DS.Spacing.md : DS.Spacing.sm }

    var body: some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            // Header: icon + label + relative date
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: metric.resolvedIconName)
                    .font(headerFont)
                    .foregroundStyle(metric.category.themeColor)
                Text(metric.name)
                    .font(headerFont)
                    .foregroundStyle(.secondary)

                if metric.isHistorical, let label = metric.date.relativeLabel {
                    Spacer()
                    Text(label)
                        .font(isRegular ? .caption : .caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Value (separated from unit) + change badge with SF Symbol
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(metric.formattedNumericValue)
                        .font(valueFont)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)

                    let unitText = metric.resolvedUnitLabel
                    if !unitText.isEmpty && metric.category != .sleep {
                        Text(unitText)
                            .font(isRegular ? .subheadline : .caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let icon = metric.changeDirectionIcon,
                   let value = metric.formattedChangeValue {
                    HStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: isRegular ? 11 : 9, weight: .bold))
                        Text(value)
                            .font(isRegular ? .caption : .caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(changeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(changeColor.opacity(0.12), in: Capsule())
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background {
            RoundedRectangle(cornerRadius: sizeClass == .regular ? DS.Radius.lg : DS.Radius.md)
                .fill(.thinMaterial)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.name), \(metric.formattedValue)")
    }

    private var changeColor: Color {
        guard let change = metric.change else { return .secondary }
        switch metric.category {
        case .hrv:
            return change > 0 ? DS.Color.positive : DS.Color.negative
        case .rhr:
            return change > 0 ? DS.Color.negative : DS.Color.positive
        case .sleep:
            return change > 0 ? DS.Color.positive : DS.Color.caution
        default:
            return change > 0 ? DS.Color.positive : .secondary
        }
    }
}
