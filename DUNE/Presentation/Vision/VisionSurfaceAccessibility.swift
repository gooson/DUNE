import Foundation

enum VisionSurfaceAccessibility {
    static let contentRoot = "vision-content-root"
    static let wellnessSleepSection = "vision-wellness-sleep-section"
    static let wellnessSleepEmptyState = "vision-wellness-sleep-empty-state"
    static let wellnessBodySection = "vision-wellness-body-section"
    static let wellnessBodyPlaceholder = "vision-wellness-body-placeholder"
    static let lifePlaceholder = "vision-life-placeholder"
    static let dashboardRoot = "vision-dashboard-root"
    static let dashboardConditionSection = "vision-dashboard-condition-section"
    static let dashboardQuickActionsSection = "vision-dashboard-quick-actions-section"
    static let dashboardHealthMetricsSection = "vision-dashboard-health-metrics-section"
    static let dashboardMockDataSection = "vision-dashboard-mock-data-section"
    static let dashboardToolbarSettings = "vision-dashboard-toolbar-settings"
    static let dashboardToolbarImmersive = "vision-dashboard-toolbar-immersive"
    static let dashboardToolbarVolumetric = "vision-dashboard-toolbar-volumetric"
    static let dashboardToolbarChart3D = "vision-dashboard-toolbar-chart3d"
    static let dashboardToolbarMockData = "vision-dashboard-toolbar-mock-data"
    static let dashboardMetricHRV = "vision-dashboard-metric-hrv"
    static let dashboardMetricRHR = "vision-dashboard-metric-rhr"
    static let dashboardMetricSleep = "vision-dashboard-metric-sleep"
    static let trainRoot = "vision-train-root"
    static let trainHeroCard = "vision-train-hero-card"
    static let trainOpenChart3DButton = "vision-train-open-chart3d-button"
    static let trainLoadingState = "vision-train-loading-state"
    static let trainUnavailableState = "vision-train-unavailable-state"
    static let trainFailedState = "vision-train-failed-state"
    static let trainSharePlayCard = "vision-train-shareplay-card"
    static let trainVoiceEntryCard = "vision-train-voice-entry-card"
    static let trainExerciseGuideCard = "vision-train-exercise-guide-card"
    static let trainMuscleMapCard = "vision-train-muscle-map-card"

    // MARK: - Dashboard Window Scene
    static let dashboardWindowActivityRecentSessions = "vision-dashboard-window-activity-recent-sessions"

    // MARK: - Volumetric Window
    static let volumetricRoot = "vision-volumetric-root"
    static let volumetricSceneStage = "vision-volumetric-scene-stage"
    static let volumetricScenePickerOrnament = "vision-volumetric-picker-ornament"
    static let volumetricScenePicker = "vision-volumetric-scene-picker"
    static let volumetricTrailingOrnament = "vision-volumetric-trailing-ornament"
    static let volumetricMetricStrip = "vision-volumetric-metric-strip"
    static let volumetricMuscleStrip = "vision-volumetric-muscle-strip"
    static let volumetricLoadingState = "vision-volumetric-loading-state"
    static let volumetricMessageState = "vision-volumetric-message-state"
    static let volumetricRetryButton = "vision-volumetric-retry-button"

    // MARK: - Immersive Space
    static let immersiveRoot = "vision-immersive-root"
    static let immersiveScene = "vision-immersive-scene"
    static let immersiveHeader = "vision-immersive-header"
    static let immersiveRefreshButton = "vision-immersive-refresh-button"
    static let immersiveCloseButton = "vision-immersive-close-button"
    static let immersiveControlPanel = "vision-immersive-control-panel"
    static let immersiveModePicker = "vision-immersive-mode-picker"
    static let immersiveLoadingState = "vision-immersive-loading-state"
    static let immersiveFailedState = "vision-immersive-failed-state"
    static let immersiveReadyPanel = "vision-immersive-ready-panel"
    static let immersiveInfoCard = "vision-immersive-info-card"
    static let immersiveRecoveryAction = "vision-immersive-recovery-action"

    // MARK: - Chart3D Window
    static let chart3DRoot = "vision-chart3d-root"
    static let chart3DPicker = "vision-chart3d-picker"
    static let chart3DCondition = "vision-chart3d-condition"
    static let chart3DTraining = "vision-chart3d-training"

    static func sectionScreenID(for section: AppSection) -> String {
        "vision-content-screen-\(section.rawValue)"
    }

    static func dashboardQuickActionID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-quick-action-\(kind.rawValue)"
    }

    static func dashboardWindowRootID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-window-\(kind.rawValue)-root"
    }

    static func dashboardWindowRefreshButtonID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-window-\(kind.rawValue)-refresh-button"
    }

    static func dashboardWindowHeroCardID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-window-\(kind.rawValue)-hero-card"
    }

    static func dashboardWindowDetailSectionID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-window-\(kind.rawValue)-detail-section"
    }

    static func dashboardWindowLoadingStateID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-window-\(kind.rawValue)-loading-state"
    }

    static func dashboardWindowUnavailableStateID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-window-\(kind.rawValue)-unavailable-state"
    }

    static func dashboardWindowMessageCardID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-window-\(kind.rawValue)-message-card"
    }

    static func volumetricSceneID(for scene: VisionSpatialSceneKind) -> String {
        "vision-volumetric-scene-\(scene.rawValue)"
    }
}
