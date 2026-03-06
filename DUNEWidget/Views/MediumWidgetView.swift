import SwiftUI

struct MediumWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: WidgetDS.Layout.headerSpacing) {
                HStack(spacing: 6) {
                    Text("DUNE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetDS.Color.textSecondary)

                    Spacer(minLength: 0)

                    if let updatedAt = entry.scoreUpdatedAt {
                        Text(updatedAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(WidgetDS.Color.textTertiary)
                            .monospacedDigit()
                    } else {
                        Text(WidgetMetricText.today)
                            .font(.caption2)
                            .foregroundStyle(WidgetDS.Color.textTertiary)
                    }
                }

                HStack(spacing: WidgetDS.Layout.columnSpacing) {
                    ForEach(entry.metrics) { metric in
                        WidgetMetricTileView(metric: metric)
                    }
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
