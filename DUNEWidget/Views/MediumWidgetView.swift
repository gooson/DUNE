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
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(message: "Open DUNE", iconFont: .title2)
    }

    private var metricTiles: some View {
        GeometryReader { _ in
            HStack(spacing: WidgetDS.Layout.columnSpacing) {
                ForEach(entry.metrics) { metric in
                    WidgetMetricTileView(metric: metric)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
