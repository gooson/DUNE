---
tags: [ci, unit-tests, notification, navigationpath, localization, swift-testing]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNE/App/ContentView.swift
  - DUNETests/NotificationExerciseDataTests.swift
  - DUNETests/ExerciseViewModelTests.swift
  - docs/plans/2026-03-08-fix-notification-test-path-regression.md
related_solutions:
  - docs/solutions/architecture/2026-03-08-navigationstack-computed-binding-gesture-regression.md
  - docs/solutions/architecture/2026-03-08-tab-scoped-notification-push-preserves-navigation-bar.md
  - docs/solutions/testing/2026-03-07-actions-unit-test-regressions.md
---

# Solution: Actions Notification Path and Locale Regressions

## Problem

GitHub Actions unit-tests job `66156049671` failed on two stacked issues once the latest
notification/navigation refactors landed.

### Symptoms

- `DUNETests/NotificationExerciseDataTests.swift` no longer compiled because it still
  referenced `NotificationPresentationPaths`, which had been removed from `ContentView`
  when navigation bindings were rewritten to fix chart gesture regressions.
- After that compile blocker was removed, `ExerciseViewModelTests.swift` still expected
  English-only `"2 sets"` / `"18 reps"` substrings from a localized summary formatter.

### Root Cause

The notification navigation refactor correctly removed the old `@State
NotificationPresentationPaths` binding owner, but the tests kept depending on that helper
type as their seam. Separately, `setSummary()` already used `String(localized:)`, but the
test continued asserting hard-coded English text.

## Solution

Restore a pure path-policy helper that is shared with tests while keeping
`NavigationStack(path:)` bound directly to four tab-scoped `@State NavigationPath`
properties, and update the summary assertion to use localized expectations.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/ContentView.swift` | Reintroduced `NotificationPresentationPaths` as a pure helper model, then used it only for path policy operations | Preserve the test seam without reviving the broken computed-binding ownership pattern |
| `DUNETests/ExerciseViewModelTests.swift` | Replaced English-only substring checks with `String(localized:)` expectations | Make the test deterministic across Korean/English simulator locales |

### Key Code

```swift
struct NotificationPresentationPaths {
    var today = NavigationPath()
    var train = NavigationPath()
    var wellness = NavigationPath()
    var life = NavigationPath()

    mutating func clearAll(except excluded: AppSection? = nil) {
        if excluded != .today && !today.isEmpty { today = NavigationPath() }
        if excluded != .train && !train.isEmpty { train = NavigationPath() }
        if excluded != .wellness && !wellness.isEmpty { wellness = NavigationPath() }
        if excluded != .life && !life.isEmpty { life = NavigationPath() }
    }
}

#expect(summary?.contains(String(localized: "\(2.formattedWithSeparator) sets")) == true)
```

## Prevention

### Checklist Addition

- [ ] Navigation helper refactor 시, tests가 의존하는 seam이 제거되면 equivalent pure helper 또는 새 테스트 seam을 같이 제공한다.
- [ ] `String(localized:)` 결과를 검증하는 테스트는 영문 하드코딩 대신 동일한 localized formatter로 기대값을 만든다.
- [ ] `NavigationStack(path:)` 관련 회귀를 막기 위해 helper 복구가 필요해도 binding owner는 직접 `@State`로 유지한다.

### Rule Addition (if applicable)

기존 `localization.md`와 navigation solution docs로 충분해 별도 rule 추가는 생략했다.

## Lessons Learned

- CI compile blocker를 하나 해결하면 그 뒤에 숨어 있던 locale/test-only failure가 바로 드러날 수 있으므로, 첫 실패만 고치고 멈추면 job 전체를 복구했다고 볼 수 없다.
- SwiftUI navigation refactor에서는 “state ownership”과 “test seam”을 분리해 생각하는 편이 안전하다. 테스트 가능성 때문에 binding source 자체를 되살리면 이전 UI regression을 다시 만들 수 있다.
