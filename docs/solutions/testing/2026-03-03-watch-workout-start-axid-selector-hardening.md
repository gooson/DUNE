---
tags: [watchos, ui-test, accessibilityidentifier, localization, smoke-test, regression]
category: testing
date: 2026-03-03
severity: important
related_files:
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNEWatch/Views/MetricsView.swift
  - DUNEWatch/Views/QuickStartAllExercisesView.swift
  - DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift
  - docs/plans/2026-03-03-watch-workout-start-axid-selectors.md
related_solutions:
  - docs/solutions/testing/2026-03-02-nightly-full-ui-test-hardening.md
  - docs/solutions/general/2026-03-03-watch-simulator-cloudkit-noaccount-fallback.md
---

# Solution: Watch Workout Start AXID Selector Hardening

## Problem

watch 운동 시작 스모크 테스트가 문자열 기반 selector를 사용해 locale/copy 변경 시 실패할 수 있었다.

### Symptoms

- 테스트가 `"Start"`, `"Complete Set"` 같은 사용자 노출 문자열에 의존
- 번역/문구 변경 시 테스트가 기능과 무관하게 깨질 위험

### Root Cause

운동 시작 핵심 UI 요소에 테스트 전용 안정 식별자(AXID)가 일부 누락되어 있어, 테스트가 텍스트 탐색을 사용했다.

## Solution

운동 시작 경로 핵심 요소에 AXID를 부여하고, 스모크 테스트를 AXID selector로 전환했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WorkoutPreviewView.swift` | Start/Outdoor/Indoor 버튼 AXID 추가 | locale 독립적인 selector 제공 |
| `MetricsView.swift` | Complete Set 버튼 AXID 추가 | 세션 진입 검증을 텍스트 의존 없이 수행 |
| `QuickStartAllExercisesView.swift` | exercise row에 `watch-quickstart-exercise-{id}` AXID 추가 | fixture exercise 탐색 안정화 |
| `WatchWorkoutStartSmokeTests.swift` | 문자열 selector 제거, AXID selector 기반으로 전환 | locale/copy 회귀 노이즈 제거 |

### Key Code

```swift
// View
.accessibilityIdentifier("watch-workout-start-button")

// UITest
let startButton = app.descendants(matching: .any)["watch-workout-start-button"].firstMatch
XCTAssertTrue(startButton.waitForExistence(timeout: 5))
```

## Prevention

### Checklist Addition

- [ ] watch UI 테스트에서 문자열 selector 대신 AXID selector를 우선 사용
- [ ] 신규 watch 시작 플로우 UI 요소에 AXID를 함께 추가
- [ ] smoke 테스트는 locale 변경과 무관하게 통과하는지 확인

### Rule Addition (if applicable)

기존 testing 문서(`nightly-full-ui-test-hardening`) 패턴을 재사용해 신규 룰 파일 추가는 생략.

## Lessons Learned

- 시뮬레이터 회귀 디버깅에서는 기능 자체 실패와 테스트 selector 실패를 분리해야 원인 파악이 빨라진다.
- watch UI 테스트도 iOS와 동일하게 AXID 기반으로 표준화해야 CI 안정성이 유지된다.
