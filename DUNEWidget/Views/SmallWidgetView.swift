import SwiftUI

struct SmallWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(entry.metrics) { metric in
                        WidgetCompactMetricView(metric: metric)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                if let lowestMetric = entry.lowestMetric {
                    HStack(spacing: 4) {
                        Image(systemName: lowestMetric.icon)
                            .font(.caption2)

                        Text(lowestMetric.title)
                            .fontWeight(.medium)

                        Text(lowestMetric.statusLabel)
                            .fontWeight(.semibold)
                    }
                    .font(.caption2)
                    .foregroundStyle(lowestMetric.tintColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                } else {
                    Text(WidgetMetricText.openDune)
                        .font(.caption2)
                        .foregroundStyle(WidgetDS.Color.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(WidgetDS.Layout.edgePadding)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(message: "Open DUNE", iconFont: .title2)
    }
}
