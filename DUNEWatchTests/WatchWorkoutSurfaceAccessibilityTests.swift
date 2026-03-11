import Testing
@testable import DUNEWatch

@Suite("WatchWorkoutSurfaceAccessibility")
struct WatchWorkoutSurfaceAccessibilityTests {
    @Test("static watch workout selectors remain unique")
    func staticSelectorsAreUnique() {
        let identifiers = [
            WatchWorkoutSurfaceAccessibility.homeRoot,
            WatchWorkoutSurfaceAccessibility.homeCarousel,
            WatchWorkoutSurfaceAccessibility.homeEmptyState,
            WatchWorkoutSurfaceAccessibility.homeAllExercisesCard,
            WatchWorkoutSurfaceAccessibility.homeBrowseAllLink,
            WatchWorkoutSurfaceAccessibility.quickStartScreen,
            WatchWorkoutSurfaceAccessibility.quickStartList,
            WatchWorkoutSurfaceAccessibility.quickStartEmpty,
            WatchWorkoutSurfaceAccessibility.quickStartCategoryPicker,
            WatchWorkoutSurfaceAccessibility.quickStartSectionRecent,
            WatchWorkoutSurfaceAccessibility.quickStartSectionPreferred,
            WatchWorkoutSurfaceAccessibility.quickStartSectionPopular,
            WatchWorkoutSurfaceAccessibility.workoutPreviewScreen,
            WatchWorkoutSurfaceAccessibility.workoutPreviewCardio,
            WatchWorkoutSurfaceAccessibility.workoutPreviewStrengthList,
            WatchWorkoutSurfaceAccessibility.workoutPreviewStarting,
            WatchWorkoutSurfaceAccessibility.workoutPreviewStartButton,
            WatchWorkoutSurfaceAccessibility.workoutPreviewCardioIndoorButton,
            WatchWorkoutSurfaceAccessibility.workoutPreviewCardioOutdoorButton,
            WatchWorkoutSurfaceAccessibility.sessionPagingRoot,
            WatchWorkoutSurfaceAccessibility.sessionPagingStrength,
            WatchWorkoutSurfaceAccessibility.sessionPagingCardio,
            WatchWorkoutSurfaceAccessibility.sessionMetricsScreen,
            WatchWorkoutSurfaceAccessibility.sessionMetricsInputCard,
            WatchWorkoutSurfaceAccessibility.sessionMetricsNextExercise,
            WatchWorkoutSurfaceAccessibility.sessionMetricsCompleteSetButton,
            WatchWorkoutSurfaceAccessibility.sessionMetricsLastSetAdd,
            WatchWorkoutSurfaceAccessibility.sessionMetricsLastSetFinish,
            WatchWorkoutSurfaceAccessibility.sessionControlsScreen,
            WatchWorkoutSurfaceAccessibility.sessionControlsEndButton,
            WatchWorkoutSurfaceAccessibility.sessionControlsPauseResumeButton,
            WatchWorkoutSurfaceAccessibility.sessionControlsSkipButton,
            WatchWorkoutSurfaceAccessibility.restTimerScreen,
            WatchWorkoutSurfaceAccessibility.restTimerCountdown,
            WatchWorkoutSurfaceAccessibility.restTimerAddTimeButton,
            WatchWorkoutSurfaceAccessibility.restTimerSkipButton,
            WatchWorkoutSurfaceAccessibility.restTimerEndButton,
            WatchWorkoutSurfaceAccessibility.setInputScreen,
            WatchWorkoutSurfaceAccessibility.setInputDoneButton,
            WatchWorkoutSurfaceAccessibility.setInputPreviousSetsButton,
            WatchWorkoutSurfaceAccessibility.setInputPreviousSetsScreen,
            WatchWorkoutSurfaceAccessibility.setInputPreviousSetsBackButton,
            WatchWorkoutSurfaceAccessibility.setInputWeightDecrementButton,
            WatchWorkoutSurfaceAccessibility.setInputWeightIncrementButton,
            WatchWorkoutSurfaceAccessibility.setInputRepsDecrementButton,
            WatchWorkoutSurfaceAccessibility.setInputRepsIncrementButton,
            WatchWorkoutSurfaceAccessibility.setInputRPEControl,
            WatchWorkoutSurfaceAccessibility.sessionSummaryScreen,
            WatchWorkoutSurfaceAccessibility.sessionSummaryStatsGrid,
            WatchWorkoutSurfaceAccessibility.sessionSummaryEffortButton,
            WatchWorkoutSurfaceAccessibility.sessionSummaryDoneButton,
            WatchWorkoutSurfaceAccessibility.sessionSummaryExerciseBreakdown,
            WatchWorkoutSurfaceAccessibility.sessionSummaryEffortSheet,
            WatchWorkoutSurfaceAccessibility.sessionSummaryEffortDoneButton
        ]

        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test("dynamic watch workout selectors keep stable naming")
    func dynamicSelectorsUseExpectedPrefixes() {
        #expect(WatchWorkoutSurfaceAccessibility.homeCard("all-exercises") == "watch-home-card-all-exercises")
        #expect(WatchWorkoutSurfaceAccessibility.quickStartExercise("ui-test-squat") == "watch-quickstart-exercise-ui-test-squat")
        #expect(WatchWorkoutSurfaceAccessibility.setInputPreviousSetRow(3) == "watch-set-input-previous-set-3")
    }
}
