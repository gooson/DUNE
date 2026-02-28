---
tags: [ui-test, xctest, accessibility, ci, smoke-test, test-plan]
date: 2026-02-28
category: solution
status: implemented
---

# UI Test Infrastructure Design

## Problem

UI tests were failing in CI due to HealthKit entitlement unavailability. Tests relied on hardcoded accessibility labels (localization-fragile), had no shared base class, and lacked systematic coverage across all app screens.

## Solution

### 1. 3-Tier AXID Naming Convention

Centralized accessibility identifier constants in `DUNEUITests/Helpers/UITestHelpers.swift`:

```
{tab}-{section}-{element}
```

Examples: `dashboard-hero-condition`, `activity-toolbar-add`, `body-form-weight`

### 2. UITestBaseCase Hierarchy

```
UITestBaseCase (--uitesting, UIInterruptionMonitor, iPad skip)
  └── SeededUITestBaseCase (--seed-mock for pre-populated data)
```

- `shouldSeedMockData` override pattern for data-seeded tests
- `UIInterruptionMonitor` auto-dismisses system permission dialogs
- iPad sidebar layout detection + XCTSkip for CI (iPhone-only)

### 3. TestDataSeeder (DEBUG-only)

- `#if DEBUG` compilation guard prevents inclusion in release builds
- `shouldSeedMockData` gated by `isRunningXCTest` runtime check
- `.task` with one-shot `@State` flag prevents re-seeding on view re-appear
- Insert order: record first, then child objects (WorkoutSet, HabitLog)

### 4. CI Test Plan Separation

- `UITests-CI.xctestplan` excludes `HealthKitPermissionUITests`
- `scripts/test-ui.sh` supports `--test-plan` argument
- Manual HealthKit permission tests in `DUNEUITests/Manual/`

### 5. Smoke Test Coverage

| Tab | Tests | Key Assertions |
|-----|-------|----------------|
| Dashboard | 6 | Tab bar, all tabs exist, settings navigation |
| Activity | 4 | Tab loads, toolbar, hero, exercise picker |
| Wellness | 5 | Tab loads, toolbar, body/injury forms |
| Life | 5 | Tab loads, toolbar, habit form, seeded hero |
| Settings | 6 | Sections exist, exercise defaults link |

## Key Decisions

1. **Launch argument (`--seed-mock`) over fixture files**: Simpler, no file management, immediate SwiftData insertion
2. **AXID enum over string literals**: Single source of truth, compile-time safety, documented active vs planned
3. **`#if DEBUG` + `isRunningXCTest` double guard**: Prevents test code from shipping in production AND from accidental activation
4. **`static let` for ProcessInfo checks**: Avoids body hot-path re-evaluation

## Prevention

- New UI elements should add AXID constant when `.accessibilityIdentifier()` is applied
- Mark planned (unapplied) AXID constants with `// Planned` comment
- All form tests use AXID constants, not localized button labels
- `navigateToSettings()` and similar helpers must use AXID, not `app.buttons["label"]`

## Files

| File | Role |
|------|------|
| `DUNEUITests/Helpers/UITestHelpers.swift` | AXID constants + XCUIApplication extensions |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | Base test class hierarchy |
| `DUNE/App/TestDataSeeder.swift` | Mock data seeding (DEBUG-only) |
| `DUNE/App/DUNEApp.swift` | `--seed-mock` branch in app body |
| `DUNEUITests/UITests-CI.xctestplan` | CI test plan (excludes HK tests) |
| `scripts/test-ui.sh` | Test runner with `--test-plan` support |
| `DUNEUITests/Smoke/*.swift` | Per-tab smoke tests |
