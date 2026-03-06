import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: WidgetDS.Layout.rowSpacing) {
                headerRow

                VStack(spacing: WidgetDS.Layout.rowSpacing) {
                    ForEach(entry.metrics) { metric in
                        WidgetMetricRowView(metric: metric)
                    }
                }

                Spacer(minLength: 0)

                footerRow
            }
            .padding(WidgetDS.Layout.edgePadding)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("DUNE")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            if let updatedAt = entry.scoreUpdatedAt {
                Text(updatedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(WidgetDS.Color.textTertiary)
                    .monospacedDigit()
            } else {
                Text(WidgetMetricText.today)
                    .font(.caption)
                    .foregroundStyle(WidgetDS.Color.textTertiary)
            }
        }
    }

    private var footerRow: some View {
        HStack(spacing: 6) {
            if let lowestMetric = entry.lowestMetric {
                Image(systemName: lowestMetric.icon)
                    .font(.caption2)
                    .foregroundStyle(lowestMetric.tintColor)

                Text(lowestMetric.title)
                    .fontWeight(.medium)

                Text(lowestMetric.statusLabel)
                    .fontWeight(.semibold)
                    .foregroundStyle(lowestMetric.tintColor)
            } else {
                Text(WidgetMetricText.openDune)
                    .foregroundStyle(WidgetDS.Color.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(WidgetDS.Color.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(message: "Open DUNE", iconFont: .largeTitle)
    }
}
