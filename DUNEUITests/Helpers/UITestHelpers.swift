import XCTest

// MARK: - Accessibility Identifier Constants (3-tier: {tab}-{section}-{element})

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
    // Planned — identifiers not yet applied to views
    static let dashboardPinnedGrid = "dashboard-pinned-grid"
    static let dashboardWeatherCard = "dashboard-weather-card"
    static let dashboardCoachingCard = "dashboard-coaching-card"
    static let dashboardSectionCondition = "dashboard-section-condition"
    static let dashboardSectionActivity = "dashboard-section-activity"
    static let dashboardSectionBody = "dashboard-section-body"

    // MARK: - Activity Tab (active: hero, toolbar-add)
    static let activityHeroReadiness = "activity-hero-readiness"
    static let activityToolbarAdd = "activity-toolbar-add"
    static let activityQuickStartSearch = "activity-quickstart-search"
    static let waveRefreshIndicator = "wave-refresh-indicator"
    // Planned — identifiers not yet applied to views
    static let activitySectionMuscleMap = "activity-section-musclemap"
    static let activitySectionWeeklyStats = "activity-section-weeklystats"
    static let activitySectionVolume = "activity-section-volume"
    static let activitySectionPR = "activity-section-pr"
    static let activitySectionConsistency = "activity-section-consistency"
    static let activitySectionExerciseMix = "activity-section-exercisemix"
    static let activitySectionRecent = "activity-section-recent"

    // MARK: - Wellness Tab (active: hero, toolbar-add, add-menu items)
    static let wellnessHeroScore = "wellness-hero-score"
    static let wellnessToolbarAdd = "wellness-toolbar-add"
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

    // MARK: - Exercise Picker
    static let pickerSearchField = "picker-search-field"
    static let pickerRootList = "picker-root-list"
    static let pickerCancelButton = "picker-cancel-button"
    static let pickerSectionRecent = "picker-section-recent"
    static let pickerSectionPopular = "picker-section-popular"

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

// MARK: - XCUIApplication Helpers

@MainActor
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
        if let tabID = tabAccessibilityID(for: tabTitle) {
            let tabBarButton = tabBars.buttons[tabID].firstMatch
            if tabBarButton.waitForExistence(timeout: 3) {
                tabBarButton.tap()
                return
            }

            let floatingTabButton = buttons[tabID].firstMatch
            if floatingTabButton.waitForExistence(timeout: 3) {
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
            if iconTab.waitForExistence(timeout: 3) {
                iconTab.tap()
            }
        }
    }

    /// Navigate via sidebar selection (iPad)
    func navigateViaSidebar(_ sectionId: String) {
        let item = buttons[sectionId]
        if item.waitForExistence(timeout: 3) {
            item.tap()
        }
    }

    /// Whether the app is running on iPad (has sidebar instead of tab bar)
    var isIPadLayout: Bool {
        !tabBars.firstMatch.exists
    }
}
