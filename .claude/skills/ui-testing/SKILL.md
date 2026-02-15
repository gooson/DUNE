---
name: ui-testing
description: "UI 테스트 작성 패턴과 iPad/iPhone 호환성 테스트 가이드. UI 테스트 관련 작업 시 참조됩니다."
agent: ui-test-expert
---

# UI Testing Patterns

## Framework & Location

- **Framework**: XCTest (`XCUIApplication`, `XCUIElement`)
- **Location**: `DailveUITests/`
- **File naming**: `{Feature}UITests.swift`
- **Run command**: `xcodebuild test -project Dailve/Dailve.xcodeproj -scheme DailveUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DailveUITests -quiet`
- **iPad command**: `xcodebuild test -project Dailve/Dailve.xcodeproj -scheme DailveUITests -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=26.2' -only-testing DailveUITests -quiet`

## Accessibility Identifier Convention

모든 테스트 가능한 요소에 `.accessibilityIdentifier()`를 추가합니다.

### Naming Pattern

`{section}-{element-type}-{name}`

### Examples

| Element | Identifier |
|---------|-----------|
| Exercise + button | `exercise-add-button` |
| Exercise save button | `exercise-save-button` |
| Exercise cancel button | `exercise-cancel-button` |
| Exercise type picker | `exercise-type-picker` |
| Exercise date picker | `exercise-date-picker` |
| Body + button | `body-add-button` |
| Body save button | `body-save-button` |
| Body weight field | `body-weight-field` |
| iPad sidebar | `sidebar-list` |
| Sidebar item | `sidebar-{section}` |

## Test Structure

```swift
final class ExerciseUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    @MainActor
    func testAddExerciseFlow() throws {
        // Navigate to Exercise tab
        app.tabBars.buttons["Activity"].tap()

        // Tap add button
        let addButton = app.buttons["exercise-add-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Verify sheet appeared
        let saveButton = app.buttons["exercise-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
    }
}
```

## iPad-Specific Testing

iPad 테스트 시 사이드바 네비게이션을 사용합니다:

```swift
@MainActor
func testIPadSidebarNavigation() throws {
    // iPad uses sidebar instead of tab bar
    let sidebar = app.tables["sidebar-list"]
    if sidebar.exists {
        sidebar.cells["sidebar-exercise"].tap()
        // Verify detail view loaded
        let addButton = app.buttons["exercise-add-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
    }
}
```

## Device Detection

```swift
var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}
```

## Test Categories

### Must-Have (필수)

| Category | Tests |
|----------|-------|
| App Launch | 앱이 정상 실행되는가 |
| Navigation | iPhone 탭/iPad 사이드바 전환 |
| Add Flow | + 버튼 → sheet → 입력 → 저장 |
| Form State | Save 버튼 disabled/enabled 상태 |
| DatePicker | DatePicker 존재 확인 |

### Nice-to-Have (선택)

| Category | Tests |
|----------|-------|
| Edit Flow | 기존 레코드 편집 |
| Delete Flow | contextMenu → 삭제 |
| Empty State | 빈 상태에서 action 버튼 동작 |
| Error State | 유효성 오류 표시 |

## Helpers

`DailveUITests/Helpers/UITestHelpers.swift`에 공통 유틸리티를 배치합니다:

```swift
extension XCUIApplication {
    func navigateToTab(_ tabName: String) {
        tabBars.buttons[tabName].tap()
    }

    func navigateViaSidebar(_ sectionId: String) {
        let sidebar = tables["sidebar-list"]
        if sidebar.waitForExistence(timeout: 3) {
            sidebar.cells[sectionId].tap()
        }
    }

    func waitAndTap(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        let element = buttons[identifier]
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }
}
```

## Launch Arguments

UI 테스트에서 HealthKit 데이터 없이 실행하기 위해 launch argument를 사용합니다:

```swift
app.launchArguments = ["--uitesting"]
```

앱 코드에서 이를 감지하여 mock 데이터를 사용하거나 HealthKit 쿼리를 건너뛸 수 있습니다.

## Anti-Patterns

- **금지**: `sleep()` 사용 → `waitForExistence(timeout:)` 사용
- **금지**: 하드코딩된 좌표 탭 → accessibilityIdentifier 사용
- **금지**: 테스트 간 상태 의존 → 각 테스트는 독립적
- **금지**: DatePicker 값 직접 조작 → 존재 확인만, 값 검증은 유닛 테스트에서
