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

                HStack {
                    if let lowestMetric = entry.lowestMetric {
                        HStack(spacing: 4) {
                            Image(systemName: lowestMetric.icon)
                                .font(.caption2)

                            Text(lowestMetric.title)
                                .fontWeight(.medium)

                            Text(lowestMetric.statusLabel)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(lowestMetric.tintColor)
                    } else {
                        Text(WidgetMetricText.openDune)
                            .foregroundStyle(WidgetDS.Color.textTertiary)
                    }

                    Spacer(minLength: 0)

                    if let updatedAt = entry.scoreUpdatedAt {
                        Text(updatedAt, style: .time)
                            .foregroundStyle(WidgetDS.Color.textTertiary)
                            .monospacedDigit()
                    } else {
                        Text(WidgetMetricText.today)
                            .foregroundStyle(WidgetDS.Color.textTertiary)
                    }
                }
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
