---
tags: [xctest, ui-test, swiftui-menu, watchos, offscreen, accessibility, ci]
category: testing
date: 2026-09-27
severity: important
related_files:
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift
  - DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift
related_solutions:
  - testing/2026-03-09-e2e-phase5-life-regression.md
  - testing/2026-03-12-watch-ui-smoke-surface-fallback-hardening.md
---

# Life 메뉴 진입과 Watch 화면 밖 운동 행 탐색

## Problem

Actions run `36265810957`에서 Life 테스트 3개와 Watch fixture 테스트 3개가 실패했다.

### Symptoms

- Life에서 추가 버튼을 누른 뒤 습관 이름 입력 필드를 찾지 못했다.
- Watch All Exercises에서 `watch-quickstart-exercise-ui-test-squat`을 찾지 못했다.
- 최초 Watch 수정 검증에서는 동일한 원인으로 화면 밖 Crunch 행 탐색도 실패했다.

### Root Cause

Life의 추가 버튼은 이제 Menu다. 테스트는 `+ → New Habit → 폼` 중 메뉴 선택 단계를 생략했다.

Watch 접근성 계층을 실제 xcresult에서 확인한 결과, 목록은 `CollectionView[watch-quickstart-screen]`으로 노출됐고 운동 행의 AXID는 유지됐다. 작은 화면에는 Popular의 Plank만 보였으며 Squat은 아래쪽에 있었다. 식별자가 존재한다는 사실만으로 화면 밖 lazy 행을 즉시 찾거나 누를 수는 없다. 따라서 Watch 제품의 접근성 구조를 변경할 필요는 없었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| UITestHelpers.swift | `openLifeNewHabitForm()`에서 추가 메뉴와 New Habit을 누른 뒤 이름 필드까지 대기 | 실제 사용자 경로와 폼 준비 상태 확인 |
| LifeSmokeTests.swift / LifeRegressionTests.swift | 공통 폼 진입 헬퍼 사용 | 메뉴 계약 중복 제거 |
| WatchUITestBaseCase.swift | `findQuickStartExercise(identifier:maxSwipes:)` 추가 | 정확한 목록 내부에서 정확한 행 탐색 |
| WatchHomeSmokeTests / WatchPlankTimerTests / WatchWorkoutFlowSmokeTests | Squat·Plank·Crunch 진입을 공통 헬퍼로 통합 | offscreen 행의 동일한 문제 예방 |

최신 main에도 Life 메뉴 AXID와 `openLifeNewHabitForm()`이 추가돼 있었다. 병합 시 그 이름을 유지하고 폼 readiness 검증을 보강했다. Watch의 main 시스템 권한 alert 처리도 보존했다.

### Key Code

```swift
guard waitAndTap(AXID.lifeToolbarAdd, timeout: timeout) else { return false }
guard waitAndTap(AXID.lifeToolbarNewHabit, timeout: timeout) else { return false }
return textFields[AXID.habitFormName].firstMatch.waitForExistence(timeout: timeout)
```

Watch는 `quickStartList` 또는 `quickStartScreen` AXID를 가진 table/collectionView/scrollView를 찾는다. 그 컨테이너 내부의 정확한 운동 ID에 대해 `exists && isHittable`을 확인하고 최대 6회만 스크롤한다. 실패하면 accessibility hierarchy를 첨부하고 다른 운동을 대신 선택하지 않는다.

## Validation

- 원본 Watch 실패를 로컬에서 재현하고 xcresult 계층과 스크린샷으로 화면 밖 행임을 확인했다.
- 최초 수정 Watch 전체 실행은 10개 중 9개 통과했고 원래 CI의 3개 실패는 모두 통과했다. 남은 Crunch 탐색도 동일 헬퍼로 수정했다.
- main 병합 후 앱 빌드 성공: `/tmp/dune-merge-main.log`.
- 최종 코드 5관점 리뷰 및 종합 코드 품질 검토에서 P1/P2/P3=0.
- 전체 최종 런타임 결과는 계획서 실행 기록에 별도로 기록한다. 부분 통과나 빌드 성공을 전체 UI 통과로 취급하지 않는다.

## iPad 회귀에서 추가 확인한 동일 패턴

iPad 전체 검증에서 Quick Start의 Popular 섹션 조회가 실패했다. 기존 스크롤 헬퍼는 `picker-root-list`를 Table로만 찾았으나, 로그에서 동일 ID의 일반 요소는 존재하고 Table은 없었다. 두 헬퍼가 정확한 목록 AXID를 사용하도록 수정하고 Popular 섹션까지 스크롤한 후 seeded 템플릿 행으로 복귀하도록 했다. 특정 UI 타입 가정과 화면 밖 요소 가정을 함께 제거하며 기존 assertion과 fixture는 유지한다.

## Prevention

- Button을 Menu로 바꾸면 테스트도 실제 메뉴 action을 선택하도록 수정한다.
- Watch의 lazy 목록 테스트는 정확한 행 ID와 hittability를 확인하고 컨테이너에 한정해 스크롤한다.
- 접근성 식별자 문제와 화면 밖 행 문제를 구분할 때 실제 실패 계층을 먼저 확인한다.
- 테스트 실패를 fixture 교체, 임의 행 선택, assertion 제거, timeout 일괄 확대로 숨기지 않는다.
- 시뮬레이터 launchd/Creating/data-missing 오류는 assertion 실패와 구분하고 최종 코드로 다시 검증한다.

기존 UI 테스트 규칙으로 예방 가능한 사례이므로 별도 `.claude` 규칙이나 CLAUDE 교정사항은 추가하지 않는다. 이 실패에 직접 연결된 활성 TODO는 없었다.

## Lessons Learned

SwiftUI List의 접근성 타입이나 루트 식별자는 런타임에 달라질 수 있다. 화면 계층의 실제 증거와 사용자 동작을 기준으로 테스트를 고치면 제품 코드를 불필요하게 변경하지 않고 회귀 계약을 유지할 수 있다.
