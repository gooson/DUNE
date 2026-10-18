---
tags: [watchos, swiftui, scroll-phase, carousel, accessibility, ui-test]
category: testing
date: 2026-10-19
severity: minor
related_files: [DUNEWatch/Views/CarouselHomeView.swift, DUNEWatch/Views/Components/ExerciseCardView.swift, DUNEWatch/Views/Components/CarouselRoutineCardView.swift, DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift]
related_solutions: []
---

# Solution: Watch 홈 시작 표시를 스크롤 상태에 맞춰 숨기기

## Problem

### Symptoms

- Watch 홈의 운동·루틴 카드마다 시작 표시가 항상 붙어 있어, 손가락이나 Digital Crown으로 카드를 넘기는 동안에도 행동 요소가 계속 보였다.
- UI 테스트에서 화면 밖 카드도 `isHittable`로 판정돼, 반복 스와이프가 목표 카드를 지나치거나 화면 밖 카드를 탭했다.

### Root Cause

시작 표시는 카드 내부에 고정되어 있었고 캐러셀의 스크롤 단계와 연결되지 않았다. Watch 접근성 계층의 `isHittable`만으로는 해당 카드의 중심이 현재 화면 안에 있는지 알 수 없었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/CarouselHomeView.swift` | `onScrollPhaseChange`로 스크롤 여부를 카드에 전달하고 `LazyVStack` 사용 | 스크롤 중 숨기고 idle에서 복귀하며 화면 밖 카드 평가를 줄임 |
| `DUNEWatch/Views/Components/ExerciseCardView.swift`, `CarouselRoutineCardView.swift` | 시작 표시의 투명도와 접근성 노출을 상태에 연결 | 카드 높이를 유지하면서 시각·접근성 상태 일치 |
| `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift` | 스크롤 뒤 화면 안에 중심이 있는 카드를 선택하고 시작 표시·미리보기 이동 확인 | 화면 밖 `isHittable` 오판 방지 |

### Key Code

```swift
.onScrollPhaseChange { _, newPhase in
    isCarouselScrolling = newPhase.isScrolling
}
```

카드의 시작 표시에는 `opacity`를 사용해 44pt 행동 영역의 공간을 그대로 유지한다. 스크롤 중에는 접근성에서 숨기고, 정지하면 다시 노출한다.

### Verification

- Watch 빌드와 최종 `build-for-testing` 통과. `LazyVStack` 변경 전 seeded Watch UI 테스트 `testStartPromptReturnsAfterCarouselScroll` 1건 통과.
- `LazyVStack` 변경 후 같은 UI 테스트 재실행은 CoreSimulatorService 연결 실패로 테스트가 0건 실행됐다. 최신 코드의 스크롤 정렬 동작은 다시 확인해야 한다.
- 실패 시 녹화에서 이동 중 시작 표시가 숨는 프레임을 확인했고, 통과한 테스트에서 정지 후 표시와 운동 미리보기 이동을 확인했다.
- 실제 화면맵 H01·H02·H03을 44mm Watch 시뮬레이터 화면으로 갱신했다. 캡처 전용 테스트는 H03 카드 위치 판정에서 실패했으므로 각 이미지의 출처와 실패 경위를 `capture-index.json`에 남겼다.

## Prevention

### Checklist Addition

- [ ] Watch 스크롤 UI 테스트는 `isHittable`과 함께 카드 중심이 화면 안에 있는지 확인한다.
- [ ] 스크롤 중 요소를 숨길 때 카드 높이가 변하지 않는지 확인한다.
- [ ] 실패한 테스트의 화면을 디자인맵에 사용할 때는 실제 PNG를 보고 실패 경위를 출처에 기록한다.

### Rule Addition

새 공통 규칙은 추가하지 않는다. 기존 제스처 재현 검증과 실제 화면맵 갱신 규칙을 사용한다.

## Lessons Learned

Watch UI 자동화에서는 화면 밖 카드가 접근성상 탭 가능으로 보고될 수 있으므로, 보이는 카드를 골라야 한다. 시각 효과는 카드의 기하를 바꾸지 않는 편이 스크롤 정렬을 안정적으로 유지한다.
