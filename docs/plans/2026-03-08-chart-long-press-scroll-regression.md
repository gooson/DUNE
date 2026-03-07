---
topic: chart-long-press-scroll-regression
date: 2026-03-08
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-08-common-chart-selection-overlay.md
  - docs/solutions/general/2026-02-17-chart-ux-layout-stability.md
  - docs/solutions/architecture/2026-02-23-activity-detail-view-v2-patterns.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-chart-long-press-scroll-regression.md
---

# Implementation Plan: Chart Long-Press Scroll Regression

## Context

공통 차트 selection UX를 `chartOverlay + DragGesture` 기반으로 바꾼 뒤, scrollable detail chart에서 롱프레스와 수평 스크롤이 경쟁하는 회귀가 발생했다. 사용자는 주간 차트에서 롱프레스할 때 visible range가 밀려 월간처럼 좁아진 느낌을 받고, 일부 차트에서는 차트 자체 스크롤도 자연스럽지 않게 느낀다.

동시에 Activity 계열 차트는 여전히 `chartXSelection` + 상단 고정 overlay를 사용하고 있어, shared chart와 interaction 규약이 분리된 상태다. 이번 작업은 단일 회귀 핫픽스가 아니라 “selection이 있는 모든 차트의 공통 interaction contract”를 재정의하는 작업이다.

## Requirements

### Functional

- scrollable shared chart에서 롱프레스해도 current period/visible range가 흔들리지 않아야 한다
- selection이 활성화되기 전에는 차트 가로 스크롤이 정상 동작해야 한다
- selection이 활성화된 뒤에는 스크롤과 selection이 동시에 경쟁하지 않아야 한다
- selection 종료 후 차트 가로 스크롤이 즉시 복구되어야 한다
- shared chart와 Activity chart가 동일한 long-press selection UX를 사용해야 한다
- floating overlay, snapped point, haptic trigger 기준이 모든 차트에서 일관되어야 한다

### Non-functional

- 기존 chart styling, axis, trend line, accessibility descriptor를 유지해야 한다
- `scrollPosition` 기반 visible range label과 summary recomputation을 깨뜨리면 안 된다
- 공통 로직은 유지보수 가능한 gesture state machine 수준으로 추출되어야 한다
- 순수 상태/수학은 unit test로 고정하고, 가능하면 실제 gesture 회귀는 UI test로 보완해야 한다
- 변경 범위가 커도 차트별 mark rendering 로직까지 과도하게 추상화하지 않는다

## Approach

공통 차트 상호작용을 `gesture state machine + shared selection helper` 구조로 재정리한다. 핵심은 overlay를 유지하되, selection 진입 경로를 scroll-friendly long-press contract로 바꾸는 것이다.

현재 문제의 중심은 `chartOverlay` 위에 항상 붙는 `DragGesture(minimumDistance: 0)`가 scroll host와 경쟁한다는 점이다. 이를 다음 방식으로 정리한다.

1. `ChartSelectionInteraction`에 selection phase와 scroll policy를 표현하는 state machine을 도입한다
2. 차트별 gesture는 동일한 long-press sequence 규약을 사용한다
3. scrollable chart는 selection phase에 따라 scroll 허용/잠금을 일관되게 처리한다
4. snapped point, anchor conversion, floating overlay 배치는 기존 shared helper를 재사용한다
5. Activity chart도 동일 helper에 편입해 앱 전체 selection 차트의 UX를 하나로 맞춘다

이번 설계는 느슨한 modifier 조합보다 state machine 수준 helper를 선호한다. 차트별로 다른 것은 데이터 포인트 매핑과 overlay 문자열뿐이고, hold activation / scroll lock / selection reset / haptic trigger는 모두 공통 정책이어야 하기 때문이다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 overlay `DragGesture`의 threshold/slop만 조정 | 변경 범위가 작음 | scroll 경쟁의 구조적 원인을 해결하지 못하고 chart scrollability 회귀가 남을 수 있음 | 기각 |
| shared chart만 수정하고 Activity chart는 유지 | 빠른 핫픽스 가능 | UX contract가 계속 분리되고 “모든 그래프 동일 UX” 요구를 만족하지 못함 | 기각 |
| gesture state machine 공통화 + Activity/shared 전체 편입 | 유지보수성, 일관성, 테스트 가능성 확보 | 초기 수정 범위가 큼 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | modify | gesture state machine, scroll policy, selection lifecycle 공통화 |
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | modify | 공통 overlay rendering은 유지하되 helper contract에 맞게 재사용 |
| `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift` | modify | scrollable shared chart interaction contract 교체 |
| `DUNE/Presentation/Shared/Charts/BarChartView.swift` | modify | same |
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | modify | same |
| `DUNE/Presentation/Shared/Charts/RangeBarChartView.swift` | modify | same |
| `DUNE/Presentation/Shared/Charts/SleepStageChartView.swift` | modify | same |
| `DUNE/Presentation/Shared/Charts/HeartRateChartView.swift` | modify | non-scroll selection chart도 공통 contract 편입 |
| `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | modify | Activity chart를 floating long-press UX로 통합 |
| `DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift` | modify | same |
| `DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift` | modify | same |
| `DUNE/Presentation/Activity/TrainingReadiness/Components/ReadinessTrendChartView.swift` | modify | same |
| `DUNE/Presentation/Activity/TrainingReadiness/Components/SubScoreTrendChartView.swift` | modify | same |
| `DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift` | modify | embedded trend chart를 same contract로 정리 |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | modify | shared chart UI test 관찰용 identifier 노출 가능성 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift` | modify | scrollable shared chart UI test 관찰용 identifier 노출 가능성 |
| `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift` | modify | Activity detail chart UI test 진입/관찰 지점 추가 가능성 |
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | detail 진입 selector 보강 가능성 |
| `DUNETests/ChartSelectionInteractionTests.swift` | modify | 상태 전이, scroll policy, snap 회귀 테스트 확대 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | 신규 chart/detail AXID 추가 |
| `DUNEUITests/` 신규 테스트 파일 | add | representative chart interaction UI regression test 추가 |

## Implementation Steps

### Step 1: 공통 gesture state machine 재설계

- **Files**: `ChartSelectionInteraction.swift`, 필요 시 `ChartSelectionOverlay.swift`
- **Changes**:
  - selection phase (`idle`, `tracking hold`, `selecting`)를 표현하는 공통 state 추가
  - scrollable chart가 참조할 `allowsScroll` 또는 동등한 정책 API 제공
  - long-press activation, cancellation, reset, snapped-point haptic trigger 기준을 helper로 통일
  - 기존 overlay layout / nearest-point / anchor helper는 유지하면서 새 state contract에 맞게 통합
- **Verification**:
  - 공통 helper만으로 scroll policy와 selection lifecycle을 설명할 수 있음
  - 각 차트가 phase 상태만 참조해 동일한 scroll/selection 규칙을 적용할 수 있음

### Step 2: scrollable shared chart 회귀 수정

- **Files**: `AreaLineChartView.swift`, `BarChartView.swift`, `DotLineChartView.swift`, `RangeBarChartView.swift`, `SleepStageChartView.swift`
- **Changes**:
  - overlay-level drag 경쟁을 줄이는 방향으로 gesture entrypoint를 교체
  - selection 활성화 이전에는 scroll 허용, 활성화 이후에는 scroll lock 적용
  - visible range가 selection 시작 중 밀리지 않도록 selection lifecycle과 `chartScrollableAxes` 연동 수정
  - 기존 floating overlay, snapped selection, accessibility descriptor 유지
- **Verification**:
  - 주간 chart에서 long press 시 visible range label이 불필요하게 변하지 않음
  - 일반 drag scroll은 유지되고 selection 종료 후 즉시 복구됨

### Step 3: Activity + non-scroll charts까지 동일 UX 편입

- **Files**: `HeartRateChartView.swift`, `DailyVolumeChartView.swift`, `TrainingLoadChartView.swift`, `StackedVolumeBarChartView.swift`, `ReadinessTrendChartView.swift`, `SubScoreTrendChartView.swift`, `ExerciseTypeDetailView.swift`
- **Changes**:
  - 기존 `chartXSelection` + top overlay 차트를 floating long-press selection contract로 마이그레이션
  - static chart에도 snapped point / overlay / haptic 규칙을 shared helper로 통일
  - chart별 포인트 선택 조건(`sameDay`, `nearestPoint`, stacked day total`)만 chart-local로 유지
- **Verification**:
  - shared/activity 구분 없이 selection overlay 위치와 selection indicator 동작이 일관됨
  - Activity 차트도 동일한 selection trigger와 overlay 스타일을 사용함

### Step 4: 테스트 관찰성 보강과 회귀 테스트 추가

- **Files**: `ChartSelectionInteractionTests.swift`, `UITestHelpers.swift`, detail view/Activity entry 파일, 신규 `DUNEUITests` 파일
- **Changes**:
  - unit test에 scroll policy, activation/cancel, reset, snapped point/haptic trigger 기준 추가
  - UI test용 chart/detail accessibility identifier 추가
  - 대표 경로 2개를 우선 커버:
    - shared scrollable chart: `ConditionScoreDetailView` 또는 `MetricDetailView`
    - Activity chart: `WeeklyStatsDetailView`
  - UI test에서 long press 후 range/overlay state가 안정적인지, drag scroll이 여전히 가능한지 확인
- **Verification**:
  - unit test 통과
  - 최소 1개 이상의 chart interaction UI regression test 추가 및 통과

### Step 5: 품질 게이트 및 마무리

- **Files**: 변경 파일 전체
- **Changes**:
  - 불필요한 debug state/임시 코드 제거
  - build/test 및 리뷰 준비
- **Verification**:
  - iOS build/test 결과 확보
  - 변경사항 커밋 가능 상태 정리

## Edge Cases

| Case | Handling |
|------|----------|
| hold 직전 손가락이 약간 흔들리는 경우 | activation slop과 cancel 정책을 state machine에 명시 |
| selection이 시작되기 전 chart가 약간 scroll된 경우 | selection 시작 시 visible range가 흔들리지 않도록 scroll policy를 phase 기준으로 보정 |
| selection 종료 후 scroll lock이 남는 경우 | phase reset을 공통 helper에서 강제 |
| non-scroll chart와 scrollable chart의 계약 차이 | 동일 state machine을 사용하되 scroll policy만 optional로 적용 |
| stacked bar처럼 한 날짜에 여러 segment가 있는 경우 | day-level point 매핑을 chart-local helper로 유지 |
| period change 후 stale selection 잔존 | 기존 `.id(period)` 또는 equivalent reset 패턴 유지 |
| UI test에서 chart target을 직접 잡기 어려운 경우 | chart container와 visible-range/overlay 상태에 AXID를 부여해 관찰성 확보 |

## Testing Strategy

- Unit tests:
  - `DUNETests/ChartSelectionInteractionTests.swift`에 state machine 전이, activation/cancel, scroll policy, nearest snap, overlay layout 테스트 추가
- Integration tests:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests -quiet`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNEUITests -quiet`
- Manual verification:
  - shared detail chart의 `week/month/6M/year`에서 long press + scroll 확인
  - `WeeklyStatsDetailView`, `TrainingReadinessDetailView`, `TrainingVolumeDetailView`의 chart selection 확인
  - selection 종료 후 chart scroll이 즉시 복구되는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| scrollable chart의 gesture 교체가 오히려 selection 진입을 어렵게 만듦 | Medium | High | shared helper로 threshold를 일원화하고 unit/UI test로 회귀 고정 |
| Activity chart 편입 과정에서 각 차트의 point mapping 차이로 selection이 어색해짐 | Medium | Medium | chart-local mapping만 남기고 공통 정책과 분리 |
| UI test가 simulator gesture 불안정으로 flaky 해짐 | Medium | Medium | seeded path + 명시적 AXID + 최소한의 representative assertion으로 안정화 |
| 변경 파일 수가 많아 리뷰 시 누락 위험이 생김 | Medium | Medium | plan 기준 affected files를 고정하고 Phase 3에서 diff별 6관점 리뷰 수행 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 회귀 원인은 공통 chart interaction contract와 Activity/shared 분리 상태에 모두 걸쳐 있다. 이를 helper 수준에서 통합하면 구조적으로 문제를 해결할 수 있고, seeded UI test 경로도 이미 존재해 검증 가능성이 높다.
