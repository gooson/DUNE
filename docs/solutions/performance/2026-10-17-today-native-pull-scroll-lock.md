---
tags: [swiftui, scrollview, refreshable, scroll-phase, navigation-title, today, ui-test]
category: performance
date: 2026-10-17
severity: important
related_files: [DUNE/Presentation/Dashboard/DashboardView.swift, DUNEUITests/Full/TodaySettingsRegressionTests.swift]
related_solutions: [docs/solutions/performance/2026-10-16-today-scroll-top-settling.md]
---

# Solution: Today 최상단 당김 뒤 카드가 제목 아래에 고정되는 문제

> 2026-10-24 재검증: idle 자동 정렬은 실제53pt 점프를 만들었고, native refresh caller도91ms 만에 취소되는 별도 결함이 확인됐다. 이 문서의 당시 성공 결과를 현재 해결 보증으로 사용하지 않는다. [확인된 원인과 남은 복귀 실패](2026-10-24-today-scroll-root-cause.md)에 중간 실패 및 미검증 범위를 기록했다.

## Problem

### Symptoms

- Today 최상단을 길게 당긴 뒤 큰 제목과 첫 Condition 카드가 겹치고, 다음 스크롤도 자연스럽게 반응하지 않았다. 다른 탭에서는 보고되지 않았다.
- 기존 UI 테스트는 짧은 당김, 반복 스와이프의 최종 위치, 테스트 전용 새로고침 버튼을 검사했다. 실제 `ScrollView`를 아래로 길게 당기는 경로는 검사하지 않았다.
- iPhone 18 Pro Max 시뮬레이터에서 실제 당김을 녹화하자 첫 카드가 시작 위치보다 약 50pt 위에 머물렀고, 1분 뒤에도 큰 제목과 겹쳤다.

### Root Cause

Today는 `.waveRefreshable`을 `ScrollViewReader` 바깥에 적용하고, `.onScrollPhaseChange`가 모든 idle 진입에서 상단 근처를 `scrollTo(top)`으로 다시 정렬했다. 실제 당김 뒤 content inset을 복구하는 경로와 관성 스와이프 종료를 같은 조건으로 취급한 것이 이번 시뮬레이터 재현의 원인 경로였다. 자동 정렬을 모두 제거하자 당김은 정상화됐지만 기존 반복 스와이프 테스트는 실패했다. 새로고침 modifier의 부착 위치와 idle 정렬의 개별 기여도는 분리 측정하지 않았으며, 둘을 함께 교정해 두 경로를 검증했다. 사용자가 제공한 10월 16일 영상은 자동 정렬 코드가 추가되기 전의 것이어서 당시 현상의 정확한 발생 원인은 별도로 확정하지 못했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `.waveRefreshable`을 실제 `ScrollView`에 적용 | 새로고침 소유 뷰와 스크롤 대상을 일치시킴 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `.decelerating → .idle`일 때만 상단 정렬 | 관성 스와이프 복귀는 유지하고 당김·새로고침 복구에는 개입하지 않음 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | 실제 아래로 당긴 뒤 카드의 시작 위치, 2초 뒤 안정성, 다음 위쪽 스와이프를 검사 | 이전 테스트가 놓친 사용자 제스처를 고정 |

### Verification

- 수정 전 Pro Max 시뮬레이터 녹화에서 실제 아래로 당긴 후 Condition 카드가 큰 제목과 겹친 상태로 1분 이상 유지됐다. 당시 UI 테스트는 새로고침 표시를 기다리다 실패했지만, 녹화로 지속적인 위치 오류를 확인했다.
- 상단 자동 정렬을 완전히 없앤 실험에서는 실제 당김 테스트가 통과했지만 기존 반복 전체 스와이프 테스트가 실패했다. 따라서 자동 정렬을 관성 종료로 제한했다.
- 최종 코드에서 실제 당김과 반복 전체 스와이프 UI 테스트가 같은 Pro Max 시뮬레이터에서 2/2 통과했다 (`.xcodebuild/today-scroll-phase-gated.log`). 이후 안정성 assertion을 바꾼 실제 당김 테스트도 다시 통과했다 (`.xcodebuild/today-scroll-final-validation.log`). 시뮬레이터를 재시작한 뒤 수동 상단 복귀와 반복 전체 스와이프 테스트가 2/2 통과했다 (`.xcodebuild/today-scroll-after-sim-reset.log`). 탭 재선택 테스트는 앞선 자동 정렬 제거 실험에서 통과했고, 해당 동작의 코드는 최종 변경에서 유지됐다.
- 최종 4개 묶음 실행은 시뮬레이터의 화면 요소 조회가 멈춰 두 테스트가 시간 제한으로 종료됐다. 앱 동작 assertion 실패는 아니었고, 시뮬레이터 재시작 후 해당 두 테스트를 재실행해 통과를 확인했다.
- 최신 main의 Today 레이아웃 변경과 병합한 뒤 Pro Max 시뮬레이터에서 실제 당김·반복 전체 스와이프가 다시 2/2 통과했다 (`.xcodebuild/today-scroll-merged-main-after-reset.log`). 첫 실행은 테스트 케이스 시작 전에 CoreSimulator 러너가 멈췄고, 해당 시뮬레이터를 재시작한 후 재검증했다.
- 뒤이어 병합한 테마 변경까지 포함한 최종 코드에서도 같은 두 회귀 테스트가 2/2 통과했다 (`.xcodebuild/today-scroll-final-theme-merge.log`). 실제 화면맵은 해당 테마 변경에서 네 기기 자세로 다시 캡처한 최신 T03을 보존했다.
- iOS 앱 빌드가 통과했다 (`.xcodebuild/today-native-build.log`).

## Prevention

### Checklist Addition

- [ ] 상단 새로고침 회귀는 테스트 전용 버튼 대신 실제 ScrollView 당김 제스처도 검사한다.
- [ ] 첫 카드의 최종 Y 좌표뿐 아니라 손을 뗀 뒤 유지되는 위치와 다음 제스처 반응을 검사한다.
- [ ] 스크롤 단계 변경에서 `scrollTo`를 호출할 때 관성 종료와 당김 새로고침 종료를 구분한다.

### Rule Addition

새 공통 규칙은 추가하지 않는다. 이 재현 테스트와 스크롤 단계 조건을 회귀 기준으로 사용한다.

## Lessons Learned

1. 기존 테스트가 통과해도 실제 당김 제스처가 빠져 있으면 새로고침 content inset의 복구 문제를 놓칠 수 있다.
2. 상단 정렬을 무조건 제거하면 과거 반복 스와이프 문제가 다시 발생한다. 서로 다른 스크롤 종료 경로를 같은 조건으로 처리하지 않아야 한다.
