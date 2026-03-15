import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: WidgetDS.Layout.rowSpacing) {
                metricRows

                footerRow
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(WidgetDS.Layout.edgePadding)
            .containerBackground(.fill.tertiary, for: .widget)
            .accessibilityIdentifier(WidgetSurfaceAccessibility.rootID(for: .large))
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
                .accessibilityIdentifier(WidgetSurfaceAccessibility.rootID(for: .large))
        }
    }

    private var footerRow: some View {
        HStack(spacing: 6) {
            if let lowestMetric = entry.lowestMetric {
                HStack(spacing: 6) {
                    Image(systemName: lowestMetric.icon)
                        .font(.caption2)
                        .foregroundStyle(lowestMetric.tintColor)

                    Text(lowestMetric.title)
                        .fontWeight(.medium)

                    Text(lowestMetric.statusLabel)
                        .fontWeight(.semibold)
                        .foregroundStyle(lowestMetric.tintColor)
                }
                .accessibilityIdentifier(WidgetSurfaceAccessibility.summaryID(for: .large))
            } else {
                Text(WidgetMetricText.openDune)
                    .foregroundStyle(WidgetDS.Color.textTertiary)
                    .accessibilityIdentifier(WidgetSurfaceAccessibility.summaryID(for: .large))
            }

            Spacer(minLength: 0)

            if let updatedAt = entry.scoreUpdatedAt {
                Text(updatedAt, style: .time)
                    .foregroundStyle(WidgetDS.Color.textTertiary)
                    .monospacedDigit()
                    .accessibilityIdentifier(WidgetSurfaceAccessibility.updatedAtID(for: .large))
            } else {
                Text(WidgetMetricText.today)
                    .foregroundStyle(WidgetDS.Color.textTertiary)
                    .accessibilityIdentifier(WidgetSurfaceAccessibility.updatedAtID(for: .large))
            }
        }
        .font(.caption2)
        .foregroundStyle(WidgetDS.Color.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityIdentifier(WidgetSurfaceAccessibility.footerID(for: .large))
    }

    private var metricRows: some View {
        GeometryReader { proxy in
            let metricCount = max(entry.metrics.count, 1)
            let totalSpacing = WidgetDS.Layout.rowSpacing * CGFloat(metricCount - 1)
            let rowHeight = max(0, (proxy.size.height - totalSpacing) / CGFloat(metricCount))

            VStack(spacing: WidgetDS.Layout.rowSpacing) {
                ForEach(entry.metrics) { metric in
                    WidgetMetricRowView(metric: metric, family: .large)
                        .frame(height: rowHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier(WidgetSurfaceAccessibility.scoredLaneID(for: .large))
        }
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(family: .large, message: "Open DUNE", iconFont: .largeTitle)
    }
}
