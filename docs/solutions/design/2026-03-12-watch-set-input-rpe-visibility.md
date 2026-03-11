---
tags: [watchos, rpe, set-input, discoverability, workout, smoke-test]
category: general
date: 2026-03-12
severity: important
related_files:
  - DUNEWatch/Views/SetInputSheet.swift
  - DUNEWatch/Views/MetricsView.swift
  - DUNEWatch/Helpers/WatchWorkoutSurfaceAccessibility.swift
  - DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-12-set-rpe-integration.md
  - docs/solutions/general/2026-03-08-watch-crown-focus-host-without-scrollview.md
---

# Solution: Watch Set Input RPE Visibility

## Problem

watch strength workout에서 per-set RPE 입력이 `MetricsView`의 별도 sheet 뒤로 숨어 있었다.

### Symptoms

- 세트 입력 sheet를 닫기 전까지 사용자는 RPE 기능이 있는지 바로 알기 어렵다.
- 무게/렙 입력 후 다시 한 번 별도 RPE sheet를 열어야 해서 set input flow가 끊긴다.
- watch smoke contract에는 set input anchor만 있었고, RPE discoverability는 고정되지 않았다.

### Root Cause

per-set RPE 통합 시 watch 화면 밀도를 줄이기 위해 `MetricsView`에 hidden sheet presenter를 두었고,
auto-present 되는 `SetInputSheet` 본문에서는 RPE를 완전히 제거했다.
그 결과 기능은 존재하지만 사용자가 set input 문맥에서 발견하기 어려운 구조가 되었다.

## Solution

RPE control을 `SetInputSheet` 본문으로 되돌리고, `MetricsView`의 별도 RPE sheet presenter는 제거했다.
사용자는 set input이 열리는 순간 `Tap to rate` 상태를 바로 볼 수 있고,
기존 `WorkoutManager.completeSet(weight:reps:rpe:)` 저장 경로는 그대로 유지된다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/SetInputSheet.swift` | `@Binding var rpe` 추가 + inline `WatchSetRPEPickerView` 배치 | set input 문맥에서 RPE 존재를 즉시 노출 |
| `DUNEWatch/Views/MetricsView.swift` | hidden RPE sheet presenter 제거, set input으로 binding 전달 | 입력 flow를 한 화면 문맥으로 정리 |
| `DUNEWatch/Helpers/WatchWorkoutSurfaceAccessibility.swift` | `watch-set-input-rpe` selector 추가 | discoverability contract를 selector로 고정 |
| `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift` | set input RPE selector assertion 추가 | PR smoke가 새 UI 계약을 감지하도록 강화 |
| `todos/082-done-p2-e2e-dunewatch-set-input-sheet.md` | selector inventory / smoke scope 갱신 | 문서와 실제 UI contract 동기화 |

### Key Code

```swift
.sheet(isPresented: $showInputSheet) {
    SetInputSheet(
        weight: $weight,
        reps: $reps,
        rpe: $rpe,
        previousSets: cachedPreviousSets
    )
}
```

```swift
private var rpeSection: some View {
    WatchSetRPEPickerView(rpe: $rpe)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.setInputRPEControl)
}
```

## Prevention

기능이 존재해도 사용자가 primary task flow 안에서 보지 못하면 사실상 숨겨진 UI로 취급해야 한다.
watch처럼 화면이 작은 타깃일수록 "별도 sheet로 빼면 단순해진다"보다 "지금 맥락에서 발견 가능한가"를 먼저 점검한다.

### Checklist Addition

- [ ] auto-present 되는 watch input surface에서 optional input 기능이 완전히 숨겨지지 않았는가?
- [ ] 새 watch UI selector가 smoke lane 또는 surface inventory에 함께 반영되었는가?
- [ ] watch crown host를 유지해야 할 때도 최소한 collapsed entry로 discoverability를 보장했는가?

### Rule Addition (if applicable)

기존 규칙 추가까지는 불필요하지만, watch interaction contract를 바꿀 때는 대응하는 E2E surface TODO와 solution 문서를 같은 변경에서 갱신한다.

## Lessons Learned

1. watch UI에서 밀도를 줄이려는 리팩터링은 기능 가시성을 먼저 다시 확인해야 한다.
2. hidden sheet는 구현을 단순화하지만, primary flow에서 빠져나온 순간 기능 discoverability를 크게 떨어뜨릴 수 있다.
3. selector inventory를 함께 고정해 두면 "보여야 하는 UI가 사라지는" 회귀를 smoke 단계에서 더 빨리 잡을 수 있다.
