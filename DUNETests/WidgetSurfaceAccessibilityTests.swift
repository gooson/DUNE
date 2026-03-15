import Testing
@testable import DUNE

@Suite("WidgetSurfaceAccessibility")
struct WidgetSurfaceAccessibilityTests {
    @Test("Widget kind and supported families stay stable")
    func widgetKindAndFamilies() {
        #expect(WidgetSurfaceAccessibility.widgetKind == "WellnessDashboardWidget")
        #expect(
            WidgetSurfaceFamily.allCases.map(\.entryRoute)
                == ["systemSmall", "systemMedium", "systemLarge"]
        )
        #expect(
            WidgetSurfaceAccessibility.supportedFamilyRoutes
                == ["systemSmall", "systemMedium", "systemLarge"]
        )
    }

    @Test("Family root and lane identifiers stay stable and unique")
    func familyIdentifiers() {
        let rootIDs = WidgetSurfaceFamily.allCases.map(WidgetSurfaceAccessibility.rootID)
        let scoredLaneIDs = WidgetSurfaceFamily.allCases.map(WidgetSurfaceAccessibility.scoredLaneID)
        let placeholderLaneIDs = WidgetSurfaceFamily.allCases.map(WidgetSurfaceAccessibility.placeholderLaneID)

        #expect(
            rootIDs
                == ["widget-small-root", "widget-medium-root", "widget-large-root"]
        )
        #expect(
            scoredLaneIDs
                == [
                    "widget-small-scored-lane",
                    "widget-medium-scored-lane",
                    "widget-large-scored-lane",
                ]
        )
        #expect(
            placeholderLaneIDs
                == [
                    "widget-small-placeholder-lane",
                    "widget-medium-placeholder-lane",
                    "widget-large-placeholder-lane",
                ]
        )
        #expect(Set(rootIDs).count == WidgetSurfaceFamily.allCases.count)
        #expect(Set(scoredLaneIDs).count == WidgetSurfaceFamily.allCases.count)
        #expect(Set(placeholderLaneIDs).count == WidgetSurfaceFamily.allCases.count)
    }

    @Test("Metric identifiers stay stable and unique across families")
    func metricIdentifiers() {
        let identifiers = WidgetSurfaceFamily.allCases.flatMap { family in
            WidgetSurfaceMetric.allCases.map { metric in
                WidgetSurfaceAccessibility.metricID(metric, family: family)
            }
        }

        #expect(
            identifiers
                == [
                    "widget-small-metric-condition",
                    "widget-small-metric-readiness",
                    "widget-small-metric-wellness",
                    "widget-medium-metric-condition",
                    "widget-medium-metric-readiness",
                    "widget-medium-metric-wellness",
                    "widget-large-metric-condition",
                    "widget-large-metric-readiness",
                    "widget-large-metric-wellness",
                ]
        )
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test("Footer and placeholder element identifiers stay stable")
    func footerAndPlaceholderIdentifiers() {
        #expect(WidgetSurfaceAccessibility.summaryID(for: .small) == "widget-small-summary")
        #expect(WidgetSurfaceAccessibility.summaryID(for: .large) == "widget-large-summary")
        #expect(WidgetSurfaceAccessibility.footerID(for: .small) == "widget-small-footer")
        #expect(WidgetSurfaceAccessibility.footerID(for: .large) == "widget-large-footer")
        #expect(WidgetSurfaceAccessibility.updatedAtID(for: .small) == "widget-small-updated-at")
        #expect(WidgetSurfaceAccessibility.updatedAtID(for: .large) == "widget-large-updated-at")
        #expect(
            WidgetSurfaceAccessibility.placeholderBrandID(for: .small)
                == "widget-small-placeholder-brand"
        )
        #expect(
            WidgetSurfaceAccessibility.placeholderIconID(for: .medium)
                == "widget-medium-placeholder-icon"
        )
        #expect(
            WidgetSurfaceAccessibility.placeholderMessageID(for: .large)
                == "widget-large-placeholder-message"
        )
    }
}
