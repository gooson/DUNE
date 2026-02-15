import SwiftUI

struct MetricCardView: View {
    let metric: HealthMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.name)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.formattedValue)
                    .font(.title2)
                    .fontWeight(.semibold)

                if let change = metric.formattedChange {
                    Text(change)
                        .font(.caption)
                        .foregroundStyle(changeColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.name), \(metric.formattedValue)")
    }

    private var changeColor: Color {
        guard let change = metric.change else { return .secondary }
        switch metric.category {
        case .hrv:
            return change > 0 ? .green : .red
        case .rhr:
            return change > 0 ? .red : .green
        case .sleep:
            return change > 0 ? .green : .orange
        default:
            return change > 0 ? .green : .secondary
        }
    }
}
