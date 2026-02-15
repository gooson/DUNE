import XCTest

// MARK: - Accessibility Identifier Constants

enum AXID {
    // Sidebar (iPad)
    static let sidebarList = "sidebar-list"
    static func sidebarItem(_ section: String) -> String { "sidebar-\(section)" }

    // Exercise
    static let exerciseAddButton = "exercise-add-button"
    static let exerciseSaveButton = "exercise-save-button"
    static let exerciseCancelButton = "exercise-cancel-button"
    static let exerciseDatePicker = "exercise-date-picker"
    static let exerciseTypePicker = "exercise-type-picker"

    // Body Composition
    static let bodyAddButton = "body-add-button"
    static let bodySaveButton = "body-save-button"
    static let bodyCancelButton = "body-cancel-button"
    static let bodyDatePicker = "body-date-picker"
    static let bodyWeightField = "body-weight-field"
    static let bodyFatField = "body-fat-field"
    static let bodyMuscleField = "body-muscle-field"
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
