import Foundation
import Testing
@testable import DUNE

@Suite("VisionWindowPlacementPlanner")
struct VisionWindowPlacementPlannerTests {
    @Test("Condition window opens to the leading side of the main window")
    func conditionUsesLeadingMainWindow() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: VisionDashboardWindowKind.condition.windowID,
            existingWindowIDs: windowIDs(nil)
        )

        #expect(relationship == .leading(VisionWindowPlacementPlanner.mainWindowID))
    }

    @Test("Activity window opens to the trailing side of the main window")
    func activityUsesTrailingMainWindow() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: VisionDashboardWindowKind.activity.windowID,
            existingWindowIDs: windowIDs(nil)
        )

        #expect(relationship == .trailing(VisionWindowPlacementPlanner.mainWindowID))
    }

    @Test("Sleep window prefers the condition window as its anchor")
    func sleepUsesConditionWindowWhenPresent() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: VisionDashboardWindowKind.sleep.windowID,
            existingWindowIDs: windowIDs(nil, VisionDashboardWindowKind.condition.windowID)
        )

        #expect(relationship == .below(VisionDashboardWindowKind.condition.windowID))
    }

    @Test("Sleep window falls back below the main window when condition is closed")
    func sleepFallsBackToMainWindow() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: VisionDashboardWindowKind.sleep.windowID,
            existingWindowIDs: windowIDs(nil)
        )

        #expect(relationship == .below(VisionWindowPlacementPlanner.mainWindowID))
    }

    @Test("Body window prefers the activity window as its anchor")
    func bodyUsesActivityWindowWhenPresent() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: VisionDashboardWindowKind.body.windowID,
            existingWindowIDs: windowIDs(nil, VisionDashboardWindowKind.activity.windowID)
        )

        #expect(relationship == .below(VisionDashboardWindowKind.activity.windowID))
    }

    @Test("Body window falls back below the main window when activity is closed")
    func bodyFallsBackToMainWindow() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: VisionDashboardWindowKind.body.windowID,
            existingWindowIDs: windowIDs(nil)
        )

        #expect(relationship == .below(VisionWindowPlacementPlanner.mainWindowID))
    }

    @Test("Chart3D window opens above the main window")
    func chart3DUsesAboveMainWindow() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: VisionWindowPlacementPlanner.chart3DWindowID,
            existingWindowIDs: windowIDs(nil)
        )

        #expect(relationship == .above(VisionWindowPlacementPlanner.mainWindowID))
    }

    @Test("Settings window always opens as a utility panel")
    func settingsUsesUtilityPanel() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: VisionWindowPlacementPlanner.settingsWindowID,
            existingWindowIDs: windowIDs(nil)
        )

        #expect(relationship == .utilityPanel)
    }

    @Test(
        "Known windows fall back to the utility panel when no anchor window is available",
        arguments: [
            VisionDashboardWindowKind.condition.windowID,
            VisionDashboardWindowKind.activity.windowID,
            VisionWindowPlacementPlanner.chart3DWindowID,
        ]
    )
    func knownWindowsWithoutAnchorsUseUtilityPanel(windowID: String) {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: windowID,
            existingWindowIDs: []
        )

        #expect(relationship == .utilityPanel)
    }

    @Test("Unknown windows fall back to the utility panel")
    func unknownWindowFallsBackToUtilityPanel() {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: "unknown-window",
            existingWindowIDs: []
        )

        #expect(relationship == .utilityPanel)
    }

    private func windowIDs(_ ids: String?...) -> Set<String?> {
        Set(ids)
    }
}
