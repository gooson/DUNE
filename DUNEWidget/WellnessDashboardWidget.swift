import SwiftUI
import WidgetKit

struct WellnessDashboardWidget: Widget {
    let kind = "WellnessDashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetScoreProvider()) { entry in
            WellnessDashboardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DUNE Today")
        .description("Condition, Readiness, and Wellness scores at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WellnessDashboardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WellnessDashboardEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

@main
struct DUNEWidgetBundle: WidgetBundle {
    var body: some Widget {
        WellnessDashboardWidget()
    }
}
