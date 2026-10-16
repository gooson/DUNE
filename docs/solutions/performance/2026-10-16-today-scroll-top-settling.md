---
tags: [swiftui, scrollview, scroll-phase, navigation-title, today, pull-to-refresh, ui-test]
category: performance
date: 2026-10-16
severity: important
related_files: [DUNE/Presentation/Dashboard/DashboardView.swift, DUNEUITests/Full/TodaySettingsRegressionTests.swift]
related_solutions: [docs/solutions/performance/2026-10-14-today-scroll-top-bounce.md]
---

# Solution: Today 상단에서 반복 스와이프 후 제목과 카드가 덜컹거리는 문제

## Problem

### Symptoms

- 실제 기기 영상에서 Today의 최상단으로 돌아갈 때 큰 제목이 접힌 상태와 펼쳐진 상태 사이에서 흔들리고 첫 Condition 카드가 시작 위치에 안정적으로 놓이지 않았다.
- 이전 회귀 테스트는 새로고침 임계값을 넘지 않는 짧은 드래그만 사용했다. 이 테스트는 통과했지만, 전체 길이의 스와이프를 반복하는 새 테스트는 Condition 카드가 처음 Y 위치로 돌아오지 않아 실패했다.

### Root Cause

이전 수정은 지표 카드의 `LazyVGrid`를 eager 행으로 바꿔 콘텐츠 높이 변동을 줄였지만, 스크롤이 최상단 근처에서 멈추는 경우는 처리하지 않았다. 실패 화면에서는 Condition 카드가 보이는데도 내비게이션 제목이 접힌 상태였으며, 상단 위치로 완전히 복귀하지 않았다. SwiftUI 내부에서 이 위치가 남는 정확한 원인은 확인하지 못했다.

SwiftData `@Query`를 Today 루트에서 분리한 실험 후에도 같은 전체 스와이프 테스트가 실패했다. 따라서 이번 재현의 해결책으로 해당 변경을 유지하지 않았다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 스크롤 단계가 idle로 바뀔 때 상단에서 130pt 이내에 남은 양의 오프셋을 시작 anchor로 정렬 | 큰 제목과 첫 카드가 중간 위치에 머무르지 않게 함 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | 아래로 스크롤한 뒤 전체 스와이프를 반복해 첫 카드의 시작 Y 위치 복귀와 새로고침 진입을 확인 | 기존 짧은 드래그 테스트가 놓친 사용자 경로를 고정 |

### Key Code

```swift
.onScrollPhaseChange { _, newPhase, context in
    guard newPhase == .idle else { return }
    let distanceFromTop = context.geometry.contentOffset.y + context.geometry.contentInsets.top
    guard distanceFromTop > 0, distanceFromTop < 130 else { return }
    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
}
```

양의 오프셋과 상단 근처에서만 정렬하므로 일반 스크롤과 아래로 당기는 동안에는 개입하지 않는다.

### Verification

- 상단 정렬 추가 전(SwiftData 분리 실험 상태): `testRepeatedFullSwipesAtTopSettleConditionHero` 실패. 실패 화면에서 제목은 접혀 있고 첫 카드가 원래 상단 위치보다 위에 있었다.
- 수정 후: 동일 테스트 통과. SwiftData 실험 변경을 되돌린 최종 코드에서 수동 상단 복귀, 반복 전체 스와이프, 탭 재선택 테스트 3건 통과.
- 새 테스트의 UI 전용 새로고침 트리거에서 wave 표시, 완료, 이후 첫 카드의 상단 위치 유지도 확인했다. 실제 사용자 데이터와 HealthKit 동기화 중 동작은 이 seeded 테스트로 확인하지 못했다.
- 실제 화면 디자인맵의 T03은 일반 iPhone, iPad, Duo 접힌 외부 화면에서 새로 캡처했다. Duo 펼친 내부 화면은 이번 실행에서 힌지 전환 수단을 확보하지 못해 이전 캡처를 새 구현의 증거로 사용하지 않는다.

## Prevention

### Checklist Addition

- [ ] 스크롤 상단 회귀는 짧은 드래그뿐 아니라 화면 아래에서 시작하는 전체 스와이프를 반복해 확인한다.
- [ ] 큰 내비게이션 제목과 첫 카드의 위치를 함께 확인한다. 카드가 보인다는 것만으로 최상단 복귀를 판정하지 않는다.
- [ ] 새로고침 표시가 시작되는지 여부를 제스처 테스트의 전제 조건으로 삼지 않는다. 실제 스크롤 위치와 새로고침 기능을 별도로 검증한다.

### Rule Addition

새 공통 규칙은 추가하지 않는다. 기존 스크롤 제스처 테스트 규칙과 이 사례의 재현 테스트를 사용한다.

## Lessons Learned

1. 영상에서 보이는 긴 스와이프를 짧은 드래그로 바꾸면 회귀 테스트가 통과해도 결함을 놓칠 수 있다.
2. 기존 카드 레이아웃 수정과 별개로, 내비게이션 큰 제목의 마지막 상단 정렬을 검증해야 한다.
3. 원인 후보였던 데이터 관찰 변경은 실패 테스트를 통과시키지 못했으므로 최종 변경에서 제외했다.
