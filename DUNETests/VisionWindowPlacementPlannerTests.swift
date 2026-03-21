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

    @Test("Smoke configuration stays disabled without launch arguments")
    func smokeConfigurationDisabledByDefault() {
        let configuration = VisionWindowPlacementSmokeConfiguration.current(arguments: [])

        #expect(configuration.mode == .disabled)
        #expect(configuration.isEnabled == false)
        #expect(configuration.shouldSeedMockData == false)
        #expect(configuration.mainWindowAutoOpenIDs.isEmpty)
        #expect(configuration.secondaryWindowAutoOpenIDs.isEmpty)
        #expect(configuration.shouldDismissMainWindow == false)
    }

    @Test("Smoke configuration enables seeded auto-open flow")
    func smokeConfigurationUsesExpectedWindowOrder() {
        let configuration = VisionWindowPlacementSmokeConfiguration.current(
            arguments: [VisionWindowPlacementSmokeConfiguration.smokeLaunchArgument]
        )

        #expect(configuration.mode == .primary)
        #expect(configuration.isEnabled)
        #expect(configuration.shouldSeedMockData)
        #expect(configuration.mainWindowAutoOpenIDs == [
            VisionDashboardWindowKind.condition.windowID,
            VisionDashboardWindowKind.activity.windowID,
            VisionDashboardWindowKind.sleep.windowID,
            VisionDashboardWindowKind.body.windowID,
            VisionWindowPlacementPlanner.chart3DWindowID,
        ])
        #expect(configuration.secondaryWindowAutoOpenIDs.isEmpty)
        #expect(configuration.shouldDismissMainWindow == false)
    }

    @Test("No-anchor smoke configuration opens settings first and continues from utility panel")
    func noAnchorSmokeConfigurationUsesSettingsContinuation() {
        let configuration = VisionWindowPlacementSmokeConfiguration.current(
            arguments: [VisionWindowPlacementSmokeConfiguration.noAnchorSmokeLaunchArgument]
        )

        #expect(configuration.mode == .noAnchor)
        #expect(configuration.isEnabled)
        #expect(configuration.shouldSeedMockData)
        #expect(configuration.mainWindowAutoOpenIDs == [
            VisionWindowPlacementPlanner.settingsWindowID,
        ])
        #expect(configuration.secondaryWindowAutoOpenIDs == [
            VisionDashboardWindowKind.condition.windowID,
            VisionWindowPlacementPlanner.chart3DWindowID,
        ])
        #expect(configuration.shouldDismissMainWindow)
    }

    @Test("Seed mock alone does not auto-open windows")
    func seedMockWithoutSmokeDoesNotAutoOpenWindows() {
        let configuration = VisionWindowPlacementSmokeConfiguration.current(
            arguments: [VisionWindowPlacementSmokeConfiguration.seedMockLaunchArgument]
        )

        #expect(configuration.mode == .disabled)
        #expect(configuration.isEnabled == false)
        #expect(configuration.shouldSeedMockData)
        #expect(configuration.mainWindowAutoOpenIDs.isEmpty)
        #expect(configuration.secondaryWindowAutoOpenIDs.isEmpty)
        #expect(configuration.shouldDismissMainWindow == false)
    }

    private func windowIDs(_ ids: String?...) -> Set<String?> {
        Set(ids)
    }
}
