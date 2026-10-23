import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: WidgetDS.Layout.rowSpacing) {
                metricRows
                Spacer(minLength: 0)
                footerRow
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(WidgetDS.Layout.edgePadding)
            .duneWidgetSurface()
            .accessibilityIdentifier(WidgetSurfaceAccessibility.rootID(for: .large))
        } else {
            placeholderView
                .duneWidgetSurface()
                .accessibilityIdentifier(WidgetSurfaceAccessibility.rootID(for: .large))
        }
    }

    private var footerRow: some View {
        HStack(spacing: 6) {
            if let lowestMetric = entry.lowestMetric {
                HStack(spacing: 6) {
                    Image(systemName: lowestMetric.icon)
                        .font(.caption2)
                        .foregroundStyle(lowestMetric.textColor)

                    Text(lowestMetric.title)
                        .fontWeight(.medium)

                    Text(lowestMetric.statusLabel)
                        .fontWeight(.semibold)
                        .foregroundStyle(lowestMetric.textColor)
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
        .privacySensitive()
    }

    private var metricRows: some View {
        VStack(spacing: WidgetDS.Layout.rowSpacing) {
            ForEach(entry.metrics) { metric in
                WidgetMetricRowView(metric: metric, family: .large)
            }
        }
        .accessibilityIdentifier(WidgetSurfaceAccessibility.scoredLaneID(for: .large))
        .privacySensitive()
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(family: .large, message: "Open DUNE", iconFont: .largeTitle)
    }
}
