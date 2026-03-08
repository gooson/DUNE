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

    // MARK: - Activity Tab (active: hero, toolbar-add)
    static let activityHeroReadiness = "activity-hero-readiness"
    static let activityToolbarAdd = "activity-toolbar-add"
    static let activityQuickStartSearch = "activity-exercise-search"
    static let waveRefreshIndicator = "wave-refresh-indicator"
    static let activitySectionMuscleMap = "activity-section-musclemap"
    static let activitySectionWeeklyStats = "activity-section-weeklystats"
    static let activitySectionVolume = "activity-section-volume"
    static let activitySectionPR = "activity-section-pr"
    static let activitySectionAchievement = "activity-section-achievement"
    static let activitySectionConsistency = "activity-section-consistency"
    static let activitySectionExerciseMix = "activity-section-exercisemix"
    static let activitySectionRecent = "activity-section-recent"
    static let activityRecentSeeAll = "activity-recent-seeall"
    static let activityTrainingReadinessDetailScreen = "activity-training-readiness-detail-screen"
    static let activityMuscleMapDetailScreen = "activity-musclemap-detail-screen"
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
    // Planned — identifiers not yet applied to views
    static let wellnessSectionPhysical = "wellness-section-physical"
    static let wellnessSectionActive = "wellness-section-active"
    static let wellnessSectionInjury = "wellness-section-injury"
    static let wellnessLinkBodyHistory = "wellness-link-bodyhistory"
    static let wellnessLinkInjuryHistory = "wellness-link-injuryhistory"

    // MARK: - Life Tab (active: hero, toolbar-add, habits section, habit toggle)
    static let lifeHeroProgress = "life-hero-progress"
    static let lifeToolbarAdd = "life-toolbar-add"
    static let lifeSectionHabits = "life-section-habits"
    static let lifeHabitToggle = "life-habit-toggle"
    static func lifeHabitActions(_ habitName: String) -> String { "life-habit-actions-\(habitName)" }
    static let lifeHabitActionEdit = "life-habit-action-edit"
    static let lifeHabitActionArchive = "life-habit-action-archive"

    // MARK: - Settings (active rows)
    static let settingsRowExerciseDefaults = "settings-row-exercisedefaults"
    static let settingsRowPreferredExercises = "settings-row-preferredexercises"
    static let settingsRowRestTime = "settings-row-resttime"
    static let settingsSectionAppearance = "settings-section-appearance"
    static let settingsRowICloudSync = "settings-row-icloud-sync"
    static let settingsRowLocationAccess = "settings-row-location-access"
    static let settingsRowWhatsNew = "settings-row-whatsnew"
    static let settingsRowVersion = "settings-row-version"

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

    // MARK: - Exercise Picker
    static let pickerSearchField = "picker-search-field"
    static let pickerRootList = "picker-root-list"
    static let pickerCancelButton = "picker-cancel-button"
    static let pickerCreateCustomButton = "picker-create-custom-button"
    static let pickerAllExercisesButton = "picker-all-exercises-button"
    static let pickerSectionRecent = "picker-section-recent"
    static let pickerSectionPopular = "picker-section-popular"
    static func pickerExerciseRow(_ exerciseID: String) -> String { "picker-row-\(exerciseID)" }
    static func pickerExerciseDetailButton(_ exerciseID: String) -> String { "picker-detail-\(exerciseID)" }

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
    static let templateFormScreen = "template-form-screen"
    static let templateFormName = "template-form-name"
    static let templateFormAddExercise = "template-form-add-exercise"
    static let templateFormSave = "template-form-save"
    static let templateFormCancel = "template-form-cancel"
    static let templateWorkoutContainerScreen = "template-workout-container-screen"
    static let templateWorkoutContainerClose = "template-workout-container-close"
    static let compoundWorkoutSetupScreen = "compound-workout-setup-screen"
    static let compoundWorkoutSetupAddExercise = "compound-workout-setup-add-exercise"
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
    static let weeklyStatsPeriodPicker = "weeklystats-period-picker"
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

    private func preferredScrollContainer() -> XCUIElement {
        let containers = [
            scrollViews.firstMatch,
            tables.firstMatch,
            collectionViews.firstMatch
        ]

        for container in containers where container.waitForExistence(timeout: 1) {
            return container
        }

        return self
    }
}
