import SwiftUI

struct MetricCardView: View {
    let metric: HealthMetric

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header: icon + label
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: metric.category.iconName)
                    .font(.caption)
                    .foregroundStyle(metric.category.themeColor)
                Text(metric.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Value + change badge
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.formattedValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                if let change = metric.formattedChange {
                    Text(change)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(changeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            changeColor.opacity(0.12),
                            in: Capsule()
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md)
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
