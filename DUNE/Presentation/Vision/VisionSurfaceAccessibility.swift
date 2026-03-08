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
}
