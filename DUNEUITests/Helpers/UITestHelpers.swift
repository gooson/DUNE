import XCTest

// MARK: - Accessibility Identifier Constants (3-tier: {tab}-{section}-{element})

enum AXID {
    // MARK: - Dashboard Tab
    static let dashboardHeroCondition = "dashboard-hero-condition"
    static let dashboardToolbarSettings = "dashboard-toolbar-settings"
    static let dashboardPinnedEdit = "dashboard-pinned-edit"
    static let dashboardPinnedGrid = "dashboard-pinned-grid"
    static let dashboardWeatherCard = "dashboard-weather-card"
    static let dashboardCoachingCard = "dashboard-coaching-card"
    static let dashboardSectionCondition = "dashboard-section-condition"
    static let dashboardSectionActivity = "dashboard-section-activity"
    static let dashboardSectionBody = "dashboard-section-body"

    // MARK: - Activity Tab
    static let activityHeroReadiness = "activity-hero-readiness"
    static let activityToolbarAdd = "activity-toolbar-add"
    static let activitySectionMuscleMap = "activity-section-musclemap"
    static let activitySectionWeeklyStats = "activity-section-weeklystats"
    static let activitySectionVolume = "activity-section-volume"
    static let activitySectionPR = "activity-section-pr"
    static let activitySectionConsistency = "activity-section-consistency"
    static let activitySectionExerciseMix = "activity-section-exercisemix"
    static let activitySectionRecent = "activity-section-recent"

    // MARK: - Wellness Tab
    static let wellnessHeroScore = "wellness-hero-score"
    static let wellnessToolbarAdd = "wellness-toolbar-add"
    static let wellnessSectionPhysical = "wellness-section-physical"
    static let wellnessSectionActive = "wellness-section-active"
    static let wellnessSectionInjury = "wellness-section-injury"
    static let wellnessLinkBodyHistory = "wellness-link-bodyhistory"
    static let wellnessLinkInjuryHistory = "wellness-link-injuryhistory"

    // MARK: - Life Tab
    static let lifeHeroProgress = "life-hero-progress"
    static let lifeToolbarAdd = "life-toolbar-add"
    static let lifeSectionHabits = "life-section-habits"

    // MARK: - Settings
    static let settingsRowWorkoutDefaults = "settings-row-workoutdefaults"
    static let settingsRowExerciseDefaults = "settings-row-exercisedefaults"
    static let settingsRowAppearance = "settings-row-appearance"
    static let settingsRowDataPrivacy = "settings-row-dataprivacy"
    static let settingsRowAbout = "settings-row-about"

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

    // MARK: - Exercise (Activity sub-view)
    static let exerciseToolbarTemplates = "exercise-toolbar-templates"
    static let exerciseToolbarCategories = "exercise-toolbar-categories"
    static let exerciseToolbarAdd = "exercise-toolbar-add"

    // MARK: - Exercise Picker
    static let pickerSearchField = "picker-search-field"
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
    /// Navigate to a tab by its visible title (iPhone)
    func navigateToTab(_ tabTitle: String) {
        let tab = tabBars.buttons[tabTitle]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
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
