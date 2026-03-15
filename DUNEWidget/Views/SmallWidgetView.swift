import SwiftUI

struct SmallWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(entry.metrics) { metric in
                        WidgetCompactMetricView(metric: metric, family: .small)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(WidgetSurfaceAccessibility.scoredLaneID(for: .small))

                Spacer(minLength: 0)

                HStack(spacing: 0) {
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
                        .accessibilityIdentifier(WidgetSurfaceAccessibility.summaryID(for: .small))
                    } else {
                        Text(WidgetMetricText.openDune)
                            .foregroundStyle(WidgetDS.Color.textTertiary)
                            .accessibilityIdentifier(WidgetSurfaceAccessibility.summaryID(for: .small))
                    }

                    Spacer(minLength: 0)

                    if let updatedAt = entry.scoreUpdatedAt {
                        Text(updatedAt, style: .time)
                            .foregroundStyle(WidgetDS.Color.textTertiary)
                            .monospacedDigit()
                            .accessibilityIdentifier(WidgetSurfaceAccessibility.updatedAtID(for: .small))
                    } else {
                        Text(WidgetMetricText.today)
                            .foregroundStyle(WidgetDS.Color.textTertiary)
                            .accessibilityIdentifier(WidgetSurfaceAccessibility.updatedAtID(for: .small))
                    }
                }
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier(WidgetSurfaceAccessibility.footerID(for: .small))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(WidgetDS.Layout.edgePadding)
            .containerBackground(.fill.tertiary, for: .widget)
            .accessibilityIdentifier(WidgetSurfaceAccessibility.rootID(for: .small))
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
                .accessibilityIdentifier(WidgetSurfaceAccessibility.rootID(for: .small))
        }
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(family: .small, message: "Open DUNE", iconFont: .title2)
    }
}
