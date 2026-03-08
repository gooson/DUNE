import Testing
@testable import DUNE

@Suite("VisionSurfaceAccessibility")
struct VisionSurfaceAccessibilityTests {
    @Test("Section screen identifiers stay stable and unique")
    func sectionScreenIdentifiers() {
        let identifiers = AppSection.allCases.map(VisionSurfaceAccessibility.sectionScreenID)

        #expect(
            identifiers
                == [
                    "vision-content-screen-today",
                    "vision-content-screen-train",
                    "vision-content-screen-wellness",
                    "vision-content-screen-life",
                ]
        )
        #expect(Set(identifiers).count == AppSection.allCases.count)
    }

    @Test("Root and placeholder identifiers stay stable")
    func placeholderIdentifiers() {
        #expect(VisionSurfaceAccessibility.contentRoot == "vision-content-root")
        #expect(VisionSurfaceAccessibility.wellnessSleepSection == "vision-wellness-sleep-section")
        #expect(VisionSurfaceAccessibility.wellnessSleepEmptyState == "vision-wellness-sleep-empty-state")
        #expect(VisionSurfaceAccessibility.wellnessBodySection == "vision-wellness-body-section")
        #expect(VisionSurfaceAccessibility.wellnessBodyPlaceholder == "vision-wellness-body-placeholder")
        #expect(VisionSurfaceAccessibility.lifePlaceholder == "vision-life-placeholder")
    }

    @Test("Chart3D identifiers stay stable")
    func chart3DIdentifiers() {
        #expect(VisionSurfaceAccessibility.chart3DRoot == "vision-chart3d-root")
        #expect(VisionSurfaceAccessibility.chart3DPicker == "vision-chart3d-picker")
        #expect(VisionSurfaceAccessibility.chart3DCondition == "vision-chart3d-condition")
        #expect(VisionSurfaceAccessibility.chart3DTraining == "vision-chart3d-training")
    }

    @Test("Dashboard identifiers stay stable and unique")
    func dashboardIdentifiers() {
        let quickActionIdentifiers = VisionDashboardWindowKind.allCases.map {
            VisionSurfaceAccessibility.dashboardQuickActionID(for: $0)
        }

        #expect(VisionSurfaceAccessibility.dashboardRoot == "vision-dashboard-root")
        #expect(VisionSurfaceAccessibility.dashboardConditionSection == "vision-dashboard-condition-section")
        #expect(VisionSurfaceAccessibility.dashboardQuickActionsSection == "vision-dashboard-quick-actions-section")
        #expect(VisionSurfaceAccessibility.dashboardHealthMetricsSection == "vision-dashboard-health-metrics-section")
        #expect(VisionSurfaceAccessibility.dashboardMockDataSection == "vision-dashboard-mock-data-section")
        #expect(VisionSurfaceAccessibility.dashboardToolbarSettings == "vision-dashboard-toolbar-settings")
        #expect(VisionSurfaceAccessibility.dashboardToolbarImmersive == "vision-dashboard-toolbar-immersive")
        #expect(VisionSurfaceAccessibility.dashboardToolbarVolumetric == "vision-dashboard-toolbar-volumetric")
        #expect(VisionSurfaceAccessibility.dashboardToolbarChart3D == "vision-dashboard-toolbar-chart3d")
        #expect(VisionSurfaceAccessibility.dashboardToolbarMockData == "vision-dashboard-toolbar-mock-data")
        #expect(VisionSurfaceAccessibility.dashboardMetricHRV == "vision-dashboard-metric-hrv")
        #expect(VisionSurfaceAccessibility.dashboardMetricRHR == "vision-dashboard-metric-rhr")
        #expect(VisionSurfaceAccessibility.dashboardMetricSleep == "vision-dashboard-metric-sleep")
        #expect(
            quickActionIdentifiers
                == [
                    "vision-dashboard-quick-action-condition",
                    "vision-dashboard-quick-action-activity",
                    "vision-dashboard-quick-action-sleep",
                    "vision-dashboard-quick-action-body",
                ]
        )
        #expect(Set(quickActionIdentifiers).count == VisionDashboardWindowKind.allCases.count)
    }

    @Test("Train identifiers stay stable and unique")
    func trainIdentifiers() {
        let identifiers = [
            VisionSurfaceAccessibility.trainRoot,
            VisionSurfaceAccessibility.trainHeroCard,
            VisionSurfaceAccessibility.trainOpenChart3DButton,
            VisionSurfaceAccessibility.trainLoadingState,
            VisionSurfaceAccessibility.trainUnavailableState,
            VisionSurfaceAccessibility.trainFailedState,
            VisionSurfaceAccessibility.trainSharePlayCard,
            VisionSurfaceAccessibility.trainVoiceEntryCard,
            VisionSurfaceAccessibility.trainExerciseGuideCard,
            VisionSurfaceAccessibility.trainMuscleMapCard,
        ]

        #expect(VisionSurfaceAccessibility.trainRoot == "vision-train-root")
        #expect(VisionSurfaceAccessibility.trainHeroCard == "vision-train-hero-card")
        #expect(VisionSurfaceAccessibility.trainOpenChart3DButton == "vision-train-open-chart3d-button")
        #expect(VisionSurfaceAccessibility.trainLoadingState == "vision-train-loading-state")
        #expect(VisionSurfaceAccessibility.trainUnavailableState == "vision-train-unavailable-state")
        #expect(VisionSurfaceAccessibility.trainFailedState == "vision-train-failed-state")
        #expect(VisionSurfaceAccessibility.trainSharePlayCard == "vision-train-shareplay-card")
        #expect(VisionSurfaceAccessibility.trainVoiceEntryCard == "vision-train-voice-entry-card")
        #expect(VisionSurfaceAccessibility.trainExerciseGuideCard == "vision-train-exercise-guide-card")
        #expect(VisionSurfaceAccessibility.trainMuscleMapCard == "vision-train-muscle-map-card")
        #expect(Set(identifiers).count == identifiers.count)
    }
}
