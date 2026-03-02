---
tags: [ios, ipad, ui-test, accessibility-id, navigation, activity-tab]
category: testing
date: 2026-03-03
severity: important
related_files:
  - DUNE/App/ContentView.swift
  - DUNEUITests/Helpers/UITestBaseCase.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Smoke/ActivitySmokeTests.swift
related_solutions:
  - docs/solutions/testing/2026-02-27-tab-reselect-scroll-regression-ui-test.md
---

# Solution: iPad Activity Tab UI Test Navigation Stability

## Problem

iPad에서 Activity 탭 UI 테스트가 스킵되거나 간헐 실패했고, 스크롤 무반응 이슈 재현 검증 자체가 불안정했다.

### Symptoms

- iPad 레이아웃에서 `Primary navigation (tab bar/sidebar) not found`로 테스트 스킵
- 로케일(ko/en)에 따라 탭 라벨 탐색이 실패
- `"활동"` 라벨 중복 매칭으로 탭 탭 동작 실패

### Root Cause

- 기존 UI 테스트는 iPhone 탭바 중심(영문 라벨) 탐색에 의존
- iPad 플로팅 탭바에서는 접근성 트리가 다르고 라벨 중복 요소가 발생
- 로케일별 라벨 차이가 테스트 탐색 조건을 깨뜨림

## Solution

iPad 전용 탐색 실패를 피하기 위해 문자열 의존 탐색을 줄이고, 탭 접근성 식별자 기반 탐색을 기본 경로로 전환했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/ContentView.swift` | 탭 라벨에 `tab-*` 접근성 ID 추가 | 로케일 무관 고정 탐색 포인트 제공 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | `navigateToTab`를 `tab-*` ID 우선 + 아이콘 ID fallback으로 변경 | 라벨 중복/로케일 변화 영향 최소화 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | 내비게이션 존재 체크를 `app.hasPrimaryNavigation()`로 단일화 | 중복 로직 제거, iPad 탐색 안정성 향상 |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | `testActivityScrollRemainsResponsive` 유지 + 로케일 독립 `testActivityTabLoads` 보강 | 실제 스크롤 반응성 회귀를 iPad에서 검증 |

### Key Code

```swift
// iPad/locale independent tab navigation path
if let tabID = tabAccessibilityID(for: tabTitle) {
    let floatingTabButton = buttons[tabID].firstMatch
    if floatingTabButton.waitForExistence(timeout: 3) {
        floatingTabButton.tap()
        return
    }
}
```

## Prevention

### Checklist Addition

- [ ] UI 테스트 탭 탐색은 사용자 표시 문자열(label) 대신 접근성 식별자를 기본으로 사용
- [ ] iPad 플로팅 탭바에서 요소 중복(firstMatch ambiguity) 가능성을 항상 점검
- [ ] 스크롤 무반응 리포트가 들어오면 iPad 시뮬레이터 smoke 테스트를 먼저 재실행

### Rule Addition (if applicable)

현 시점에서 신규 전역 룰 추가보다, 기존 UI 테스트 패턴에 "탭 접근성 ID 우선" 항목을 유지하는 것으로 충분했다.

## Lessons Learned

- iPhone에서 통과하는 탭 탐색 로직은 iPad 플로팅 탭바에서 동일하게 동작하지 않을 수 있다.
- 로케일 문자열은 테스트 탐색 키로 취약하다.
- 스크롤 반응성 문제는 단일 로드 테스트보다 반복 스와이프 시나리오가 회귀 검출에 효과적이다.
