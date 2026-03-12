import Foundation

enum WatchWorkoutSurfaceAccessibility {
    static let homeRoot = "watch-home-root"
    static let homeCarousel = "watch-home-carousel"
    static let homeEmptyState = "watch-home-empty-state"
    static let homeAllExercisesCard = "watch-home-card-all-exercises"
    static let homeBrowseAllLink = "watch-home-browse-all-link"

    static func homeCard(_ cardID: String) -> String {
        "watch-home-card-\(cardID)"
    }

    static let quickStartScreen = "watch-quickstart-screen"
    static let quickStartList = "watch-quickstart-list"
    static let quickStartEmpty = "watch-quickstart-empty"
    static let quickStartCategoryPicker = "watch-quickstart-category-picker"
    static let quickStartSectionRecent = "watch-quickstart-section-recent"
    static let quickStartSectionPreferred = "watch-quickstart-section-preferred"
    static let quickStartSectionPopular = "watch-quickstart-section-popular"

    static func quickStartExercise(_ exerciseID: String) -> String {
        "watch-quickstart-exercise-\(exerciseID)"
    }

    static let workoutPreviewScreen = "watch-workout-preview-screen"
    static let workoutPreviewCardio = "watch-workout-preview-cardio"
    static let workoutPreviewStrengthList = "watch-workout-preview-strength-list"
    static let workoutPreviewStarting = "watch-workout-preview-starting"
    static let workoutPreviewStartButton = "watch-workout-start-button"
    static let workoutPreviewCardioIndoorButton = "watch-workout-cardio-indoor-button"
    static let workoutPreviewCardioOutdoorButton = "watch-workout-cardio-outdoor-button"

    static let sessionPagingRoot = "watch-session-paging-root"
    static let sessionPagingStrength = "watch-session-paging-strength"
    static let sessionPagingCardio = "watch-session-paging-cardio"

    static let sessionMetricsScreen = "watch-session-metrics-screen"
    static let sessionMetricsInputCard = "watch-session-input-card"
    static let sessionMetricsNextExercise = "watch-session-next-exercise"
    static let sessionMetricsCompleteSetButton = "watch-session-complete-set-button"
    static let sessionMetricsLastSetAdd = "watch-session-last-set-add-set"
    static let sessionMetricsLastSetFinish = "watch-session-last-set-finish"

    static let sessionControlsScreen = "watch-session-controls-screen"
    static let sessionControlsEndButton = "watch-session-end-button"
    static let sessionControlsPauseResumeButton = "watch-session-pause-resume-button"
    static let sessionControlsSkipButton = "watch-session-skip-button"

    static let restTimerScreen = "watch-rest-timer-screen"
    static let restTimerCountdown = "watch-rest-timer-countdown"
    static let restTimerAddTimeButton = "watch-rest-timer-add-time"
    static let restTimerSkipButton = "watch-rest-timer-skip"
    static let restTimerEndButton = "watch-rest-timer-end"

    static let setInputScreen = "watch-set-input-screen"
    static let setInputDoneButton = "watch-set-input-done"
    static let setInputPreviousSetsButton = "watch-set-input-previous-sets-button"
    static let setInputPreviousSetsScreen = "watch-set-input-previous-sets-screen"
    static let setInputPreviousSetsBackButton = "watch-set-input-previous-sets-back"
    static let setInputWeightDecrementButton = "watch-set-input-weight-decrement"
    static let setInputWeightIncrementButton = "watch-set-input-weight-increment"
    static let setInputRepsDecrementButton = "watch-set-input-reps-decrement"
    static let setInputRepsIncrementButton = "watch-set-input-reps-increment"
    static let restTimerRPEBadge = "watch-rest-timer-rpe-badge"

    static func setInputPreviousSetRow(_ setNumber: Int) -> String {
        "watch-set-input-previous-set-\(setNumber)"
    }

    static let sessionSummaryScreen = "watch-session-summary-screen"
    static let sessionSummaryStatsGrid = "watch-session-summary-stats"
    static let sessionSummaryEffortButton = "watch-summary-effort-button"
    static let sessionSummaryDoneButton = "watch-session-summary-done"
    static let sessionSummaryExerciseBreakdown = "watch-session-summary-breakdown"
    static let sessionSummaryEffortSheet = "watch-session-summary-effort-sheet"
    static let sessionSummaryEffortDoneButton = "watch-session-summary-effort-done"
}
