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

    @Test("Dashboard window scene identifiers stay stable and unique")
    func dashboardWindowSceneIdentifiers() {
        let rootIdentifiers = VisionDashboardWindowKind.allCases.map(VisionSurfaceAccessibility.dashboardWindowRootID)
        let refreshIdentifiers = VisionDashboardWindowKind.allCases.map(VisionSurfaceAccessibility.dashboardWindowRefreshButtonID)
        let heroIdentifiers = VisionDashboardWindowKind.allCases.map(VisionSurfaceAccessibility.dashboardWindowHeroCardID)
        let detailIdentifiers = VisionDashboardWindowKind.allCases.map(VisionSurfaceAccessibility.dashboardWindowDetailSectionID)
        let loadingIdentifiers = VisionDashboardWindowKind.allCases.map(VisionSurfaceAccessibility.dashboardWindowLoadingStateID)
        let unavailableIdentifiers = VisionDashboardWindowKind.allCases.map(VisionSurfaceAccessibility.dashboardWindowUnavailableStateID)
        let messageIdentifiers = VisionDashboardWindowKind.allCases.map(VisionSurfaceAccessibility.dashboardWindowMessageCardID)

        #expect(
            rootIdentifiers
                == [
                    "vision-dashboard-window-condition-root",
                    "vision-dashboard-window-activity-root",
                    "vision-dashboard-window-sleep-root",
                    "vision-dashboard-window-body-root",
                ]
        )
        #expect(
            refreshIdentifiers
                == [
                    "vision-dashboard-window-condition-refresh-button",
                    "vision-dashboard-window-activity-refresh-button",
                    "vision-dashboard-window-sleep-refresh-button",
                    "vision-dashboard-window-body-refresh-button",
                ]
        )
        #expect(
            heroIdentifiers
                == [
                    "vision-dashboard-window-condition-hero-card",
                    "vision-dashboard-window-activity-hero-card",
                    "vision-dashboard-window-sleep-hero-card",
                    "vision-dashboard-window-body-hero-card",
                ]
        )
        #expect(
            detailIdentifiers
                == [
                    "vision-dashboard-window-condition-detail-section",
                    "vision-dashboard-window-activity-detail-section",
                    "vision-dashboard-window-sleep-detail-section",
                    "vision-dashboard-window-body-detail-section",
                ]
        )
        #expect(
            loadingIdentifiers
                == [
                    "vision-dashboard-window-condition-loading-state",
                    "vision-dashboard-window-activity-loading-state",
                    "vision-dashboard-window-sleep-loading-state",
                    "vision-dashboard-window-body-loading-state",
                ]
        )
        #expect(
            unavailableIdentifiers
                == [
                    "vision-dashboard-window-condition-unavailable-state",
                    "vision-dashboard-window-activity-unavailable-state",
                    "vision-dashboard-window-sleep-unavailable-state",
                    "vision-dashboard-window-body-unavailable-state",
                ]
        )
        #expect(
            messageIdentifiers
                == [
                    "vision-dashboard-window-condition-message-card",
                    "vision-dashboard-window-activity-message-card",
                    "vision-dashboard-window-sleep-message-card",
                    "vision-dashboard-window-body-message-card",
                ]
        )
        #expect(VisionSurfaceAccessibility.dashboardWindowActivityRecentSessions == "vision-dashboard-window-activity-recent-sessions")
        #expect(Set(rootIdentifiers).count == VisionDashboardWindowKind.allCases.count)
        #expect(Set(refreshIdentifiers).count == VisionDashboardWindowKind.allCases.count)
        #expect(Set(heroIdentifiers).count == VisionDashboardWindowKind.allCases.count)
        #expect(Set(detailIdentifiers).count == VisionDashboardWindowKind.allCases.count)
        #expect(Set(loadingIdentifiers).count == VisionDashboardWindowKind.allCases.count)
        #expect(Set(unavailableIdentifiers).count == VisionDashboardWindowKind.allCases.count)
        #expect(Set(messageIdentifiers).count == VisionDashboardWindowKind.allCases.count)
    }

    @Test("Volumetric identifiers stay stable and unique")
    func volumetricIdentifiers() {
        let sceneIdentifiers = VisionSpatialSceneKind.allCases.map(VisionSurfaceAccessibility.volumetricSceneID)
        let identifiers = [
            VisionSurfaceAccessibility.volumetricRoot,
            VisionSurfaceAccessibility.volumetricSceneStage,
            VisionSurfaceAccessibility.volumetricScenePickerOrnament,
            VisionSurfaceAccessibility.volumetricScenePicker,
            VisionSurfaceAccessibility.volumetricTrailingOrnament,
            VisionSurfaceAccessibility.volumetricMetricStrip,
            VisionSurfaceAccessibility.volumetricMuscleStrip,
            VisionSurfaceAccessibility.volumetricLoadingState,
            VisionSurfaceAccessibility.volumetricMessageState,
            VisionSurfaceAccessibility.volumetricRetryButton,
        ]

        #expect(VisionSurfaceAccessibility.volumetricRoot == "vision-volumetric-root")
        #expect(VisionSurfaceAccessibility.volumetricSceneStage == "vision-volumetric-scene-stage")
        #expect(VisionSurfaceAccessibility.volumetricScenePickerOrnament == "vision-volumetric-picker-ornament")
        #expect(VisionSurfaceAccessibility.volumetricScenePicker == "vision-volumetric-scene-picker")
        #expect(VisionSurfaceAccessibility.volumetricTrailingOrnament == "vision-volumetric-trailing-ornament")
        #expect(VisionSurfaceAccessibility.volumetricMetricStrip == "vision-volumetric-metric-strip")
        #expect(VisionSurfaceAccessibility.volumetricMuscleStrip == "vision-volumetric-muscle-strip")
        #expect(VisionSurfaceAccessibility.volumetricLoadingState == "vision-volumetric-loading-state")
        #expect(VisionSurfaceAccessibility.volumetricMessageState == "vision-volumetric-message-state")
        #expect(VisionSurfaceAccessibility.volumetricRetryButton == "vision-volumetric-retry-button")
        #expect(
            sceneIdentifiers
                == [
                    "vision-volumetric-scene-heartRateOrb",
                    "vision-volumetric-scene-trainingBlocks",
                    "vision-volumetric-scene-bodyHeatmap",
                ]
        )
        #expect(Set(identifiers).count == identifiers.count)
        #expect(Set(sceneIdentifiers).count == VisionSpatialSceneKind.allCases.count)
    }

    @Test("Immersive identifiers stay stable and unique")
    func immersiveIdentifiers() {
        let identifiers = [
            VisionSurfaceAccessibility.immersiveRoot,
            VisionSurfaceAccessibility.immersiveScene,
            VisionSurfaceAccessibility.immersiveHeader,
            VisionSurfaceAccessibility.immersiveRefreshButton,
            VisionSurfaceAccessibility.immersiveCloseButton,
            VisionSurfaceAccessibility.immersiveControlPanel,
            VisionSurfaceAccessibility.immersiveModePicker,
            VisionSurfaceAccessibility.immersiveLoadingState,
            VisionSurfaceAccessibility.immersiveFailedState,
            VisionSurfaceAccessibility.immersiveReadyPanel,
            VisionSurfaceAccessibility.immersiveInfoCard,
            VisionSurfaceAccessibility.immersiveRecoveryAction,
        ]

        #expect(VisionSurfaceAccessibility.immersiveRoot == "vision-immersive-root")
        #expect(VisionSurfaceAccessibility.immersiveScene == "vision-immersive-scene")
        #expect(VisionSurfaceAccessibility.immersiveHeader == "vision-immersive-header")
        #expect(VisionSurfaceAccessibility.immersiveRefreshButton == "vision-immersive-refresh-button")
        #expect(VisionSurfaceAccessibility.immersiveCloseButton == "vision-immersive-close-button")
        #expect(VisionSurfaceAccessibility.immersiveControlPanel == "vision-immersive-control-panel")
        #expect(VisionSurfaceAccessibility.immersiveModePicker == "vision-immersive-mode-picker")
        #expect(VisionSurfaceAccessibility.immersiveLoadingState == "vision-immersive-loading-state")
        #expect(VisionSurfaceAccessibility.immersiveFailedState == "vision-immersive-failed-state")
        #expect(VisionSurfaceAccessibility.immersiveReadyPanel == "vision-immersive-ready-panel")
        #expect(VisionSurfaceAccessibility.immersiveInfoCard == "vision-immersive-info-card")
        #expect(VisionSurfaceAccessibility.immersiveRecoveryAction == "vision-immersive-recovery-action")
        #expect(Set(identifiers).count == identifiers.count)
    }
}
