import SwiftUI

struct SmallWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: WidgetDS.Layout.headerSpacing) {
                HStack(spacing: 6) {
                    Text("DUNE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetDS.Color.textSecondary)

                    Spacer(minLength: 0)

                    Text(WidgetMetricText.today)
                        .font(.caption2)
                        .foregroundStyle(WidgetDS.Color.textTertiary)
                }

                HStack(spacing: 6) {
                    ForEach(entry.metrics) { metric in
                        WidgetCompactMetricView(metric: metric)
                    }
                }

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
