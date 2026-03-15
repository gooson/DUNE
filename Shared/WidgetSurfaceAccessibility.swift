enum WidgetSurfaceFamily: String, CaseIterable {
    case small
    case medium
    case large

    var entryRoute: String {
        switch self {
        case .small:
            "systemSmall"
        case .medium:
            "systemMedium"
        case .large:
            "systemLarge"
        }
    }
}

enum WidgetSurfaceMetric: String, CaseIterable {
    case condition
    case readiness
    case wellness
}

enum WidgetSurfaceAccessibility {
    static let widgetKind = "WellnessDashboardWidget"

    static let supportedFamilyRoutes = WidgetSurfaceFamily.allCases.map(\.entryRoute)

    static func rootID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-root"
    }

    static func scoredLaneID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-scored-lane"
    }

    static func placeholderLaneID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-placeholder-lane"
    }

    static func metricID(_ metric: WidgetSurfaceMetric, family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-metric-\(metric.rawValue)"
    }

    static func summaryID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-summary"
    }

    static func footerID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-footer"
    }

    static func updatedAtID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-updated-at"
    }

    static func placeholderBrandID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-placeholder-brand"
    }

    static func placeholderIconID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-placeholder-icon"
    }

    static func placeholderMessageID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-placeholder-message"
    }
}
