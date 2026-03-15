@preconcurrency import XCTest

// MARK: - Accessibility Identifier Constants (3-tier: {tab}-{section}-{element})

enum ScrollDirection {
    case up
    case down
}

enum AXID {
    // MARK: - Dashboard Tab (active: hero, settings, pinned-edit)
    static let dashboardHeroCondition = "dashboard-hero-condition"
    static let dashboardToolbarNotifications = "dashboard-toolbar-notifications"
    static let dashboardToolbarWhatsNew = "dashboard-toolbar-whatsnew"
    static let dashboardToolbarSettings = "dashboard-toolbar-settings"
    static let dashboardMorningBriefingScreen = "dashboard-morning-briefing-screen"
    static let dashboardMorningBriefingDismiss = "dashboard-morning-briefing-dismiss"
    static let dashboardPinnedEdit = "dashboard-pinned-edit"
    static let notificationsReadAllButton = "notifications-read-all-button"
    static let notificationsDeleteAllButton = "notifications-delete-all-button"
    static let notificationsOpenSettingsButton = "notifications-open-settings-button"
    static let dashboardPinnedGrid = "dashboard-pinned-grid"
    static let dashboardWeatherCard = "dashboard-weather-card"
    static let dashboardCoachingCard = "dashboard-coaching-card"
    static let dashboardSectionCondition = "dashboard-section-condition"
    static let dashboardSectionActivity = "dashboard-section-activity"
    static let dashboardSectionBody = "dashboard-section-body"
    static func dashboardMetricCard(_ category: String) -> String { "dashboard-metric-\(category)" }
    static func notificationWorkoutRow(_ workoutID: String) -> String { "notification-row-workout-\(workoutID)" }

    // MARK: - Activity Tab (active: hero, toolbar-add)
    static let activityHeroReadiness = "activity-hero-readiness"
    static let activityRootScroll = "activity-root-scroll"
    static let activityToolbarAdd = "activity-toolbar-add"
    static let activityQuickStartSearch = "activity-exercise-search"
    static let waveRefreshIndicator = "wave-refresh-indicator"
    static let waveRefreshTestTrigger = "wave-refresh-test-trigger"
    static let activitySectionMuscleMap = "activity-section-musclemap"
    static let activityMuscleMapDetailLink = "activity-musclemap-detail-link"
    static let activitySectionWeeklyStats = "activity-section-weeklystats"
    static let activitySectionVolume = "activity-section-volume"
    static let activitySectionPR = "activity-section-pr"
    static let activitySectionAchievement = "activity-section-achievement"
    static let activitySectionConsistency = "activity-section-consistency"
    static let activitySectionExerciseMix = "activity-section-exercisemix"
    static let activitySectionRecent = "activity-section-recent"
    static let activityRecentSeeAll = "activity-recent-seeall"
    static let activityRecommendedRoutineCard = "activity-recommended-routine-card"
    static let activityAIWorkoutBuilder = "activity-ai-workout-builder"
    static let activityTrainingReadinessDetailScreen = "activity-training-readiness-detail-screen"
    static let activityMuscleMapDetailScreen = "activity-musclemap-detail-screen"
    static let muscleMapDetailVolumeSection = "musclemap-detail-volume-section"
    static let muscleMapDetailRecoverySection = "musclemap-detail-recovery-section"
    static let activityMuscleMap3DScreen = "activity-musclemap-3d-screen"
    static let muscleMap3DSummaryCard = "musclemap-3d-summary-card"
    static let muscleMap3DModePicker = "musclemap-3d-mode-picker"
    static let muscleMap3DViewer = "musclemap-3d-viewer"
    static let muscleMap3DMuscleStrip = "musclemap-3d-muscle-strip"
    static let muscleMap3DResetButton = "musclemap-3d-reset-button"
    static let activityWeeklyStatsDetailScreen = "activity-weeklystats-detail-screen"
    static let activityTrainingVolumeDetailScreen = "activity-training-volume-detail-screen"
    static let activityPersonalRecordsDetailScreen = "activity-personal-records-detail-screen"
    static let activityConsistencyDetailScreen = "activity-consistency-detail-screen"
    static let activityExerciseMixDetailScreen = "activity-exercise-mix-detail-screen"
    static func activityTrainingVolumeRow(_ typeKey: String) -> String { "activity-training-volume-row-\(typeKey)" }
    static let activityExerciseTypeDetailScreen = "activity-exercise-type-detail-screen"

    // MARK: - Wellness Tab (active: hero, toolbar-add, add-menu items)
    static let wellnessHeroScore = "wellness-hero-score"
    static let wellnessToolbarAdd = "wellness-toolbar-add"
    static let wellnessCardHRV = "wellness-card-hrv"
    static let wellnessCardWeight = "wellness-card-weight"
    static let wellnessMenuBodyRecord = "wellness-menu-body-record"
    static let wellnessMenuInjury = "wellness-menu-injury"
    static let wellnessLinkBodyHistory = "wellness-link-bodyhistory"
    static let wellnessLinkInjuryHistory = "wellness-link-injuryhistory"
    static let wellnessScoreDetailScreen = "wellness-score-detail-screen"
    static let bodyHistoryDetailScreen = "body-history-detail-screen"
    static func bodyHistoryManualRow(_ index: Int) -> String { "body-history-row-manual-\(index)" }
    static let bodyHistoryEditAction = "body-history-edit-action"
    static let bodyFormScreen = "body-form-screen"
    static let injuryHistoryScreen = "injury-history-screen"
    static let injuryHistoryStats = "injury-history-stats"
    static func injuryHistoryRow(_ index: Int) -> String { "injury-history-row-\(index)" }
    static let injuryStatisticsScreen = "injury-statistics-screen"
    static let injuryDetailScreen = "injury-detail-screen"
    static let injuryDetailEdit = "injury-detail-edit"
    static let injuryDetailMarkRecovered = "injury-detail-mark-recovered"
    static let injuryFormScreen = "injury-form-screen"

    // MARK: - Life Tab (active: hero, toolbar-add, habits section, actions, history)
    static let lifeHeroProgress = "life-hero-progress"
    static let lifeToolbarAdd = "life-toolbar-add"
    static let lifeSectionHabits = "life-section-habits"
    static let lifeHabitToggle = "life-habit-toggle"
    static func lifeHabitRow(_ habitName: String) -> String { "life-habit-row-\(habitName)" }
    static func lifeHabitActions(_ habitName: String) -> String { "life-habit-actions-\(habitName)" }
    static let lifeHabitActionEdit = "life-habit-action-edit"
    static let lifeHabitActionSnooze = "life-habit-action-snooze"
    static let lifeHabitActionSkip = "life-habit-action-skip"
    static let lifeHabitActionHistory = "life-habit-action-history"
    static let lifeHabitActionArchive = "life-habit-action-archive"
    static let lifeHabitHistoryScreen = "life-habit-history-screen"
    static let lifeHabitHistoryEmpty = "life-habit-history-empty"
    static let lifeHabitHistoryClose = "life-habit-history-close"
    static func lifeHabitHistoryRow(_ index: Int) -> String { "life-habit-history-row-\(index)" }

    // MARK: - Settings (active rows)
    static let settingsRowExerciseDefaults = "settings-row-exercisedefaults"
    static let settingsRowPreferredExercises = "settings-row-preferredexercises"
    static let settingsRowRestTime = "settings-row-resttime"
    static let settingsSectionAppearance = "settings-section-appearance"
    static let settingsRowICloudSync = "settings-row-icloud-sync"
    static let settingsRowLocationAccess = "settings-row-location-access"
    static let settingsRowWhatsNew = "settings-row-whatsnew"
    static let settingsRowVersion = "settings-row-version"
    static let settingsButtonSeedAdvancedMockData = "settings-button-seed-advanced-mock-data"
    static let settingsButtonResetMockData = "settings-button-reset-mock-data"

    // MARK: - What's New
    static let whatsNewScreen = "whatsnew-screen"
    static func whatsNewRow(_ feature: String) -> String { "whatsnew-row-\(feature)" }
    static func whatsNewArtwork(_ feature: String, style: String) -> String {
        "whatsnew-artwork-\(feature)-\(style)"
    }

    // MARK: - Today Detail Surfaces
    static let conditionScoreDetailScreen = "condition-score-detail-screen"
    static func metricDetailScreen(_ category: String) -> String { "metric-detail-screen-\(category)" }
    static let metricDetailShowAllData = "metric-detail-show-all-data"
    static func allDataScreen(_ category: String) -> String { "all-data-screen-\(category)" }
    static let allDataEmptyState = "all-data-empty-state"
    static let weatherDetailScreen = "weather-detail-screen"
    static let notificationHubScreen = "notification-hub-screen"
    static let notificationsEmptyState = "notifications-empty-state"
    static let pinnedMetricsEditorScreen = "pinned-metrics-editor-screen"
    static let pinnedMetricsEditorCancel = "pinned-metrics-editor-cancel"
    static let pinnedMetricsEditorDone = "pinned-metrics-editor-done"
    static let cloudSyncConsentView = "cloud-sync-consent-view"
    static let cloudSyncConsentEnable = "cloud-sync-consent-enable-button"
    static let cloudSyncConsentLocalOnly = "cloud-sync-consent-local-button"

    // MARK: - Body Form
    static let bodyFormSave = "body-form-save"
    static let bodyFormCancel = "body-form-cancel"
    static let bodyFormDate = "body-form-date"
    static let bodyFormWeight = "body-form-weight"
    static let bodyFormFat = "body-form-fat"
    static let bodyFormMuscle = "body-form-muscle"

    // MARK: - Injury Form
    static let injuryFormSave = "injury-form-save"
    static let injuryFormCancel = "injury-form-cancel"
    static let injuryFormBodyPart = "injury-form-bodypart"
    static let injuryFormSide = "injury-form-side"
    static let injuryFormStartDate = "injury-form-startdate"
    static let injuryFormEndDate = "injury-form-enddate"
    static let injuryFormRecoveredToggle = "injury-form-recovered-toggle"
    static let injuryFormMemo = "injury-form-memo"
    static func injuryFormSeverity(_ name: String) -> String { "injury-form-severity-\(name)" }

    // MARK: - Habit Form
    static let habitFormSave = "habit-form-save"
    static let habitFormCancel = "habit-form-cancel"
    static let habitFormName = "habit-form-name"
    static let habitFormType = "habit-form-type"
    static func habitFormTypeOption(_ type: String) -> String { "habit-form-type-\(type)" }
    static let habitFormGoalValue = "habit-form-goalvalue"
    static let habitFormGoalUnit = "habit-form-goalunit"
    static let habitFormFrequency = "habit-form-frequency"
    static let habitFormFrequencyDaily = "habit-form-frequency-daily"
    static let habitFormFrequencyWeekly = "habit-form-frequency-weekly"

    // MARK: - Exercise (Activity sub-view)
    static let exerciseToolbarTemplates = "exercise-toolbar-templates"
    static let exerciseToolbarCategories = "exercise-toolbar-categories"
    static let exerciseToolbarAdd = "exercise-toolbar-add"
    static let exerciseMenuSingle = "exercise-menu-single"
    static let exerciseMenuCompound = "exercise-menu-compound"
    static let exerciseViewScreen = "exercise-view-screen"
    static func exerciseRow(_ exerciseID: String) -> String { "exercise-row-\(exerciseID)" }
    static let exerciseSessionViewHistory = "exercise-session-view-history"
    static let exerciseHistoryScreen = "exercise-history-screen"
    static let exerciseStartScreen = "exercise-start-screen"
    static let exerciseStartButton = "exercise-start-button"
    static let exerciseDetailScreen = "exercise-detail-screen"
    static let exerciseDetailClose = "exercise-detail-close"
    static let exerciseDetailStart = "exercise-detail-start"
    static let createCustomExerciseScreen = "create-custom-exercise-screen"
    static let createCustomExerciseName = "create-custom-exercise-name"
    static let createCustomExerciseCreate = "create-custom-exercise-create"
    static func createCustomExerciseMuscle(_ muscle: String) -> String { "create-custom-exercise-muscle-\(muscle)" }

    // MARK: - Exercise Picker
    static let pickerSearchField = "picker-search-field"
    static let pickerRootList = "picker-root-list"
    static let pickerCancelButton = "picker-cancel-button"
    static let pickerCreateCustomButton = "picker-create-custom-button"
    static let pickerAllExercisesButton = "picker-all-exercises-button"
    static let pickerHideAllButton = "picker-hide-all-button"
    static let pickerClearFilters = "picker-clear-filters"
    static let pickerSectionRecent = "picker-section-recent"
    static let pickerSectionPreferred = "picker-section-preferred"
    static let pickerSectionPopular = "picker-section-popular"
    static let pickerSectionTemplates = "picker-section-templates"
    static let pickerSectionAll = "picker-section-all"
    static let pickerFilterCategoryScroll = "picker-filter-category-scroll"
    static let pickerFilterMuscleScroll = "picker-filter-muscle-scroll"
    static let pickerFilterEquipmentScroll = "picker-filter-equipment-scroll"
    static func pickerExerciseRow(_ exerciseID: String) -> String { "picker-row-\(exerciseID)" }
    static func pickerExerciseDetailButton(_ exerciseID: String) -> String { "picker-detail-\(exerciseID)" }
    static func pickerTemplateRow(_ slug: String) -> String { "picker-template-\(slug)" }
    static func pickerFilterCategory(_ slug: String) -> String { "picker-filter-category-\(slug)" }
    static func pickerFilterUserCategory(_ slug: String) -> String { "picker-filter-user-category-\(slug)" }
    static func pickerFilterMuscle(_ slug: String) -> String { "picker-filter-muscle-\(slug)" }
    static func pickerFilterEquipment(_ slug: String) -> String { "picker-filter-equipment-\(slug)" }

    // MARK: - Workout Session
    static let workoutSessionScreen = "workout-session-screen"
    static let workoutSessionDone = "workout-session-done"
    static let workoutSessionCompleteSet = "workout-session-complete-set"
    static let workoutSessionLastSetSheet = "workout-session-last-set-sheet"
    static let workoutSessionAddSet = "workout-session-add-set"
    static let workoutSessionFinish = "workout-session-finish"
    static func workoutSessionField(_ name: String) -> String { "workout-session-field-\(name)" }
    static let workoutCompletionSheet = "workout-completion-sheet"
    static let workoutCompletionDone = "workout-completion-done"

    // MARK: - Templates / Compound
    static let workoutTemplateListScreen = "workout-template-list-screen"
    static let workoutTemplateListAdd = "workout-template-list-add"
    static func workoutTemplateRow(_ name: String) -> String {
        let slug = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "workout-template-row-\(slug)"
    }
    static func workoutTemplateEdit(_ name: String) -> String {
        let slug = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "workout-template-edit-\(slug)"
    }
    static let templateFormScreen = "template-form-screen"
    static let templateFormName = "template-form-name"
    static let templateFormAIPrompt = "template-form-ai-prompt"
    static let templateFormAIGenerate = "template-form-ai-generate"
    static let templateFormAddExercise = "template-form-add-exercise"
    static let templateFormSave = "template-form-save"
    static let templateFormCancel = "template-form-cancel"
    static let templateWorkoutContainerScreen = "template-workout-container-screen"
    static let templateWorkoutContainerClose = "template-workout-container-close"
    static let compoundWorkoutSetupScreen = "compound-workout-setup-screen"
    static let compoundWorkoutSetupSelectionCount = "compound-workout-setup-selection-count"
    static let compoundWorkoutSetupAddExercise = "compound-workout-setup-add-exercise"
    static func compoundWorkoutSetupRow(_ exerciseID: String) -> String { "compound-workout-setup-row-\(exerciseID)" }
    static let compoundWorkoutSetupStart = "compound-workout-setup-start"
    static let compoundWorkoutScreen = "compound-workout-screen"

    // MARK: - Cardio
    static let cardioStartScreen = "cardio-start-screen"
    static let cardioStartIndoor = "cardio-start-indoor"
    static let cardioStartOutdoor = "cardio-start-outdoor"
    static let cardioSessionScreen = "cardio-session-screen"
    static let cardioSessionEnd = "cardio-session-end"
    static let cardioSessionConfirmEnd = "cardio-session-confirm-end"
    static let cardioSessionSummaryScreen = "cardio-session-summary-screen"
    static let cardioSessionSummarySave = "cardio-session-summary-save"

    // MARK: - Notification / HealthKit Detail
    static let healthkitWorkoutDetailScreen = "healthkit-workout-detail-screen"
    static let notificationTargetNotFoundScreen = "notification-target-not-found-screen"

    // MARK: - User Categories
    static let userCategoryManagementScreen = "user-category-management-screen"
    static let userCategoryAdd = "user-category-add"
    static let userCategoryEditScreen = "user-category-edit-screen"
    static let userCategoryName = "user-category-name"
    static let userCategorySave = "user-category-save"

    // MARK: - Chart Detail
    static let detailChartSurface = "detail-chart-surface"
    static let detailChartVisibleRange = "detail-chart-visible-range"
    static let chartSelectionOverlay = "chart-selection-overlay"
    static let chartSelectionProbe = "chart-selection-probe"
    static let weeklyStatsChartDailyVolume = "weeklystats-chart-daily-volume"
    static let weeklyStatsChartVisibleRange = "weeklystats-chart-visible-range"
    static let trainingVolumeChartDailyVolume = "training-volume-chart-daily-volume"
    static let trainingVolumeChartDailyVolumeSelectionProbe = "training-volume-chart-daily-volume-selection-probe"
    static let trainingVolumeDailyVolumeVisibleRange = "training-volume-daily-volume-visible-range"
    static let weeklyStatsPeriodPicker = "weeklystats-period-picker"
    static let trainingVolumeChartTrainingLoad = "training-volume-chart-training-load"
    static let trainingVolumeChartTrainingLoadSelectionProbe = "training-volume-chart-training-load-selection-probe"
    static let trainingVolumeChartVisibleRange = "training-volume-chart-visible-range"
    static let trainingReadinessChartTrend = "trainingreadiness-chart-trend"

    // MARK: - Sidebar (iPad)
    static let sidebarNavList = "sidebar-nav-list"
    static func sidebarNavItem(_ section: String) -> String { "sidebar-nav-\(section)" }
}

// MARK: - System Permission Alert Handling

extension XCTestCase {
    /// Registers an interruption monitor that auto-accepts system permission alerts
    /// (Location, HealthKit, Notifications, etc.).
    /// Call in `setUpWithError()` before `app.launch()`.
    nonisolated func addSystemPermissionMonitor() {
        _ = addUIInterruptionMonitor(withDescription: "System Permission Alert") { alert in
            MainActor.assumeIsolated {
                // Location: "Allow While Using App" (preferred) or "Allow Once"
                let allowWhileUsing = alert.buttons["Allow While Using App"]
                if allowWhileUsing.exists {
                    allowWhileUsing.tap()
                    return true
                }

                let allowOnce = alert.buttons["Allow Once"]
                if allowOnce.exists {
                    allowOnce.tap()
                    return true
                }

                // Generic "Allow" (HealthKit, Notifications with allow, etc.)
                let allow = alert.buttons["Allow"]
                if allow.exists {
                    allow.tap()
                    return true
                }

                // "OK" button
                let ok = alert.buttons["OK"]
                if ok.exists {
                    ok.tap()
                    return true
                }

                // Notifications: "Don't Allow" (we don't need push for UI tests)
                let dontAllow = alert.buttons["Don't Allow"]
                if dontAllow.exists {
                    dontAllow.tap()
                    return true
                }

                return false
            }
        }
    }
}

// MARK: - XCUIApplication Helpers

extension XCUIApplication {
    private func tabIconID(for tabTitle: String) -> String? {
        switch tabTitle {
        case "Today":
            "heart.text.clipboard"
        case "Activity":
            "flame"
        case "Wellness":
            "leaf.fill"
        case "Life":
            "checklist"
        default:
            nil
        }
    }

    private func tabAccessibilityID(for tabTitle: String) -> String? {
        switch tabTitle {
        case "Today":
            "tab-today"
        case "Activity":
            "tab-activity"
        case "Wellness":
            "tab-wellness"
        case "Life":
            "tab-life"
        default:
            nil
        }
    }

    @discardableResult
    func waitAndTap(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let buttonPredicate = NSPredicate(format: "identifier == %@", identifier)
        let buttonCandidates = [
            buttons[identifier].firstMatch,
            descendants(matching: .button).matching(buttonPredicate).firstMatch
        ]

        for button in buttonCandidates {
            let remainingTime = max(0, deadline.timeIntervalSinceNow)
            if button.exists || button.waitForExistence(timeout: remainingTime) {
                button.tap()
                return true
            }
        }

        let element = descendants(matching: .any)[identifier].firstMatch
        let remainingTime = max(0, deadline.timeIntervalSinceNow)
        guard element.exists || element.waitForExistence(timeout: remainingTime) else { return false }
        element.tap()
        return true
    }

    func hasPrimaryNavigation(timeout: TimeInterval = 8) -> Bool {
        if tabBars.firstMatch.waitForExistence(timeout: timeout) {
            return true
        }

        let tabIDs = ["tab-today", "tab-activity", "tab-wellness", "tab-life"]
        for tabID in tabIDs {
            if buttons[tabID].waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }

    /// Navigate to a tab by its visible title (iPhone)
    func navigateToTab(_ tabTitle: String) {
        let titledTabButton = tabBars.buttons[tabTitle].firstMatch
        if titledTabButton.exists || titledTabButton.waitForExistence(timeout: 1) {
            titledTabButton.tap()
            return
        }

        if let tabID = tabAccessibilityID(for: tabTitle) {
            let identifiedTab = descendants(matching: .any)[tabID].firstMatch
            if identifiedTab.waitForExistence(timeout: 3) {
                identifiedTab.tap()
                return
            }

            let tabBarButton = tabBars.buttons[tabID].firstMatch
            if tabBarButton.exists || tabBarButton.waitForExistence(timeout: 1) {
                tabBarButton.tap()
                return
            }

            let floatingTabButton = buttons[tabID].firstMatch
            if floatingTabButton.exists || floatingTabButton.waitForExistence(timeout: 1) {
                floatingTabButton.tap()
                return
            }
        }

        let titledTabBarButton = tabBars.buttons[tabTitle].firstMatch
        if titledTabBarButton.waitForExistence(timeout: 3) {
            titledTabBarButton.tap()
            return
        }

        let titledFloatingButton = buttons[tabTitle].firstMatch
        if titledFloatingButton.waitForExistence(timeout: 3) {
            titledFloatingButton.tap()
            return
        }

        if let iconID = tabIconID(for: tabTitle) {
            let iconPredicate = NSPredicate(format: "identifier == %@", iconID)
            let iconTab = buttons.matching(iconPredicate).firstMatch
            if iconTab.exists || iconTab.waitForExistence(timeout: 1) {
                iconTab.tap()
                return
            }
        }
    }

    /// Navigate via sidebar selection (iPad)
    @discardableResult
    func navigateViaSidebar(_ sectionId: String, maxSwipes: Int = 6) -> Bool {
        scrollToElementIfNeeded(sectionId, maxSwipes: maxSwipes)

        let item = descendants(matching: .any)[sectionId].firstMatch
        if item.waitForExistence(timeout: 3) {
            item.tap()
            return true
        }

        return false
    }

    /// Whether the app is running on iPad (has sidebar instead of tab bar)
    var isIPadLayout: Bool {
        !tabBars.firstMatch.exists
    }

    @discardableResult
    func scrollToElementIfNeeded(
        _ identifier: String,
        maxSwipes: Int = 8,
        direction: ScrollDirection = .up,
        timeoutPerCheck: TimeInterval = 1
    ) -> Bool {
        let element = descendants(matching: .any)[identifier].firstMatch
        for _ in 0..<maxSwipes where !element.waitForExistence(timeout: timeoutPerCheck) {
            let scrollContainer = preferredScrollContainer()
            switch direction {
            case .up:
                scrollContainer.swipeUp()
            case .down:
                scrollContainer.swipeDown()
            }
        }
        return element.exists
    }

    @discardableResult
    func scrollToHittableElementIfNeeded(
        _ identifier: String,
        maxSwipes: Int = 8,
        direction: ScrollDirection = .up,
        timeoutPerCheck: TimeInterval = 1
    ) -> Bool {
        let element = descendants(matching: .any)[identifier].firstMatch

        if !element.waitForExistence(timeout: timeoutPerCheck) {
            _ = scrollToElementIfNeeded(
                identifier,
                maxSwipes: maxSwipes,
                direction: direction,
                timeoutPerCheck: timeoutPerCheck
            )
        }

        for _ in 0..<maxSwipes where !(element.exists && element.isHittable) {
            let scrollContainer = preferredScrollContainer()
            switch direction {
            case .up:
                scrollContainer.swipeUp()
            case .down:
                scrollContainer.swipeDown()
            }
        }

        return element.exists && element.isHittable
    }

    @discardableResult
    func scrollToPickerElementIfNeeded(
        _ identifier: String,
        maxSwipes: Int = 6,
        direction: ScrollDirection = .up,
        timeoutPerCheck: TimeInterval = 0.25
    ) -> Bool {
        let element = descendants(matching: .any)[identifier].firstMatch
        let pickerList = tables[AXID.pickerRootList].firstMatch

        guard pickerList.waitForExistence(timeout: 5) else {
            return element.exists
        }

        for _ in 0..<maxSwipes {
            if element.exists || element.waitForExistence(timeout: timeoutPerCheck) {
                return true
            }

            switch direction {
            case .up:
                pickerList.swipeUp()
            case .down:
                pickerList.swipeDown()
            }
        }

        return element.exists
    }

    @discardableResult
    func scrollToHittablePickerElementIfNeeded(
        _ identifier: String,
        maxSwipes: Int = 6,
        direction: ScrollDirection = .up,
        timeoutPerCheck: TimeInterval = 0.25
    ) -> Bool {
        let element = descendants(matching: .any)[identifier].firstMatch

        guard scrollToPickerElementIfNeeded(
            identifier,
            maxSwipes: maxSwipes,
            direction: direction,
            timeoutPerCheck: timeoutPerCheck
        ) else {
            return false
        }

        let pickerList = tables[AXID.pickerRootList].firstMatch
        guard pickerList.waitForExistence(timeout: 5) else {
            return element.exists && element.isHittable
        }

        for _ in 0..<maxSwipes where !(element.exists && element.isHittable) {
            switch direction {
            case .up:
                pickerList.swipeUp()
            case .down:
                pickerList.swipeDown()
            }
        }

        return element.exists && element.isHittable
    }

    @discardableResult
    func scrollToLifeHabit(
        named habitName: String,
        maxSwipes: Int = 8,
        timeoutPerCheck: TimeInterval = 1
    ) -> Bool {
        _ = scrollToElementIfNeeded(
            AXID.lifeSectionHabits,
            maxSwipes: Swift.max(2, maxSwipes / 2),
            timeoutPerCheck: timeoutPerCheck
        )

        let habitRow = descendants(matching: .any)[AXID.lifeHabitRow(habitName)].firstMatch
        let habitLabel = staticTexts[habitName].firstMatch
        let actionsButton = descendants(matching: .any)[AXID.lifeHabitActions(habitName)].firstMatch
        let scrollContainer = tables.firstMatch.exists ? tables.firstMatch : scrollViews.firstMatch

        for _ in 0..<maxSwipes {
            if habitRow.waitForExistence(timeout: timeoutPerCheck)
                || habitLabel.waitForExistence(timeout: timeoutPerCheck)
                || actionsButton.waitForExistence(timeout: timeoutPerCheck) {
                return true
            }

            if scrollContainer.exists {
                scrollContainer.swipeUp()
            } else {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: timeoutPerCheck))
            }
        }

        return habitRow.exists || habitLabel.exists || actionsButton.exists
    }

    @discardableResult
    func scrollToLifeHabitActionsButton(
        named habitName: String,
        maxSwipes: Int = 8,
        timeoutPerCheck: TimeInterval = 1
    ) -> Bool {
        let actionsButton = descendants(matching: .any)[AXID.lifeHabitActions(habitName)].firstMatch
        let _ = scrollToLifeHabit(named: habitName, maxSwipes: maxSwipes, timeoutPerCheck: timeoutPerCheck)
        let scrollContainer = tables.firstMatch.exists ? tables.firstMatch : scrollViews.firstMatch

        for _ in 0..<maxSwipes {
            if actionsButton.waitForExistence(timeout: timeoutPerCheck), actionsButton.isHittable {
                return true
            }

            if scrollContainer.exists {
                scrollContainer.swipeUp()
            } else {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: timeoutPerCheck))
            }
        }

        return actionsButton.exists && actionsButton.isHittable
    }

    @discardableResult
    func openLifeHabitActions(
        named habitName: String,
        maxSwipes: Int = 8,
        timeoutPerCheck: TimeInterval = 1
    ) -> Bool {
        let actionsButton = descendants(matching: .any)[AXID.lifeHabitActions(habitName)].firstMatch
        if scrollToLifeHabitActionsButton(
            named: habitName,
            maxSwipes: maxSwipes,
            timeoutPerCheck: timeoutPerCheck
        ) {
            actionsButton.tap()
            return true
        }

        _ = scrollToLifeHabit(named: habitName, maxSwipes: maxSwipes, timeoutPerCheck: timeoutPerCheck)

        let row = descendants(matching: .any)[AXID.lifeHabitRow(habitName)].firstMatch
        if row.waitForExistence(timeout: timeoutPerCheck) {
            row.press(forDuration: 1.2)
            return true
        }

        let label = staticTexts[habitName].firstMatch
        if label.waitForExistence(timeout: timeoutPerCheck) {
            label.press(forDuration: 1.2)
            return true
        }

        return false
    }

    @discardableResult
    func scrollToElementInPrimaryFormIfNeeded(
        _ identifier: String,
        maxSwipes: Int = 6,
        timeoutPerCheck: TimeInterval = 1
    ) -> Bool {
        let element = descendants(matching: .any)[identifier].firstMatch
        if element.waitForExistence(timeout: timeoutPerCheck) {
            return true
        }

        let formContainer = tables.firstMatch.exists ? tables.firstMatch : scrollViews.firstMatch
        for _ in 0..<maxSwipes where !element.waitForExistence(timeout: timeoutPerCheck) {
            formContainer.swipeUp()
        }

        return element.exists
    }

    @discardableResult
    func scrollToInjuryEndDateIfNeeded(
        maxSwipes: Int = 6,
        timeoutPerCheck: TimeInterval = 1
    ) -> Bool {
        let identifiedElement = descendants(matching: .any)[AXID.injuryFormEndDate].firstMatch
        let labeledElement = staticTexts["End Date"].firstMatch
        if identifiedElement.waitForExistence(timeout: timeoutPerCheck)
            || labeledElement.waitForExistence(timeout: timeoutPerCheck) {
            return true
        }

        let formContainer = tables.firstMatch.exists ? tables.firstMatch : scrollViews.firstMatch
        for _ in 0..<maxSwipes {
            formContainer.swipeUp()
            if identifiedElement.waitForExistence(timeout: timeoutPerCheck)
                || labeledElement.waitForExistence(timeout: timeoutPerCheck) {
                return true
            }
        }

        return identifiedElement.exists || labeledElement.exists
    }

    @discardableResult
    func setSwitch(
        _ identifier: String,
        to isOn: Bool,
        fallbackLabel: String? = nil,
        timeout: TimeInterval = 5
    ) -> Bool {
        let switchControl = switches[identifier].firstMatch
        let genericControl = descendants(matching: .any)[identifier].firstMatch
        let toggle = switchControl.exists ? switchControl : genericControl
        guard toggle.waitForExistence(timeout: timeout) else { return false }
        if switchState(of: toggle) == isOn { return true }

        let tapTargets: [XCUIElement] = [
            toggle,
            fallbackLabel.map { staticTexts[$0].firstMatch },
            fallbackLabel.map { buttons[$0].firstMatch }
        ].compactMap { $0 }

        for target in tapTargets where target.exists {
            target.tap()
            if switchState(of: toggle) == isOn { return true }
        }

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return switchState(of: toggle) == isOn
    }

    @discardableResult
    func dismissModalIfPresent(
        cancelIdentifiers: [String] = [],
        timeout: TimeInterval = 2
    ) -> Bool {
        for identifier in cancelIdentifiers {
            let button = descendants(matching: .any)[identifier].firstMatch
            if button.waitForExistence(timeout: timeout) {
                button.tap()
                return true
            }
        }

        for label in ["Cancel", "Done", "Close"] {
            let button = buttons[label].firstMatch
            if button.waitForExistence(timeout: 1) {
                button.tap()
                return true
            }
        }

        let visibleSheet = sheets.firstMatch
        if visibleSheet.waitForExistence(timeout: 1) {
            visibleSheet.swipeDown()
            return true
        }

        return false
    }

    func pullToRefresh(
        in container: XCUIElement? = nil,
        from triggerElement: XCUIElement? = nil,
        attemptCount: Int = 2
    ) {
        let scrollContainer = container ?? preferredScrollContainer()

        for attempt in 0..<attemptCount {
            let start: XCUICoordinate
            let end: XCUICoordinate

            if let triggerElement {
                let startY = attempt == 0 ? 0.30 : 0.20
                let dragDistance = attempt == 0 ? 260.0 : 320.0
                start = triggerElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                end = start.withOffset(CGVector(dx: 0, dy: dragDistance))
            } else {
                let startY = attempt == 0 ? 0.18 : 0.12
                let endY = attempt == 0 ? 0.86 : 0.92
                start = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                end = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
            }

            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    @discardableResult
    func fillTextInput(
        _ identifier: String,
        with value: String,
        clearExisting: Bool = true,
        timeout: TimeInterval = 5
    ) -> Bool {
        let textField = textFields[identifier].firstMatch
        if textField.waitForExistence(timeout: timeout) {
            clearAndType(in: textField, value: value, clearExisting: clearExisting)
            return true
        }

        let textView = textViews[identifier].firstMatch
        if textView.waitForExistence(timeout: timeout) {
            clearAndType(in: textView, value: value, clearExisting: clearExisting)
            return true
        }

        return false
    }

    private func clearAndType(in element: XCUIElement, value: String, clearExisting: Bool) {
        element.tap()

        if clearExisting {
            let existingValue = (element.value as? String) ?? ""
            if !existingValue.isEmpty, !existingValue.hasPrefix("Optional(") {
                let deleteText = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count)
                element.typeText(deleteText)
            }
        }

        element.typeText(value)
    }

    private func switchState(of element: XCUIElement) -> Bool? {
        switch element.value {
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            switch string.lowercased() {
            case "1", "on", "true":
                return true
            case "0", "off", "false":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private func preferredScrollContainer() -> XCUIElement {
        let prioritizedContainers = [
            tables[AXID.pickerRootList].firstMatch,
            descendants(matching: .any)[AXID.activityRootScroll].firstMatch
        ]

        for container in prioritizedContainers where container.exists && container.isHittable {
            return container
        }

        for container in prioritizedContainers where container.exists && !container.frame.isEmpty {
            return container
        }

        let containerQueries = [
            tables,
            scrollViews,
            collectionViews
        ]

        for query in containerQueries {
            if let hittableContainer = query.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) {
                return hittableContainer
            }
        }

        for query in containerQueries {
            if let visibleContainer = query.allElementsBoundByIndex.first(where: { $0.exists && !$0.frame.isEmpty }) {
                return visibleContainer
            }
        }

        return self
    }
}
