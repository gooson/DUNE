import SwiftUI

struct MediumWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: 0) {
                metricTiles
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(WidgetDS.Layout.edgePadding)
            .containerBackground(.fill.tertiary, for: .widget)
            .accessibilityIdentifier(WidgetSurfaceAccessibility.rootID(for: .medium))
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
                .accessibilityIdentifier(WidgetSurfaceAccessibility.rootID(for: .medium))
        }
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(family: .medium, message: "Open DUNE", iconFont: .title2)
    }

    private var metricTiles: some View {
        GeometryReader { _ in
            HStack(spacing: WidgetDS.Layout.columnSpacing) {
                ForEach(entry.metrics) { metric in
                    WidgetMetricTileView(metric: metric, family: .medium)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(WidgetSurfaceAccessibility.scoredLaneID(for: .medium))
        }
    }
}
