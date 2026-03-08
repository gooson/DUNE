---
topic: training-volume-daily-volume-scroll-and-training-load-alignment
date: 2026-03-08
status: draft
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-03-08-training-load-daily-volume-scroll-history.md
  - docs/solutions/architecture/2026-03-08-chart-scroll-domain-sparse-data.md
  - docs/solutions/general/2026-03-08-chart-scrollable-axes-visible-domain.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-chart-scroll-common-logic.md
---

# Implementation Plan: Training Volume Daily Volume Scroll And Training Load Date Alignment

## Context

`TrainingVolumeDetailView`에는 두 개의 일별 막대 차트가 있다.

1. 상단 `일일 볼륨` stacked bar chart
2. 하단 `트레이닝 부하` chart

최근 변경으로 `WeeklyStats`의 일일 볼륨과 `Training Load` 차트에 scroll infra가 추가됐지만, 실제 사용자 화면 기준으로는 두 가지 회귀가 남아 있다.

- `TrainingVolumeDetail`의 `일일 볼륨`은 여전히 현재 기간 데이터만 보여 과거 데이터로 스크롤할 수 없다.
- `트레이닝 부하`는 헤더 range는 현재 주를 가리키지만, 실제 막대 표시 범위가 하루 앞당겨진 것처럼 보여 최신 날짜 bin 정렬이 맞지 않는다.

## Requirements

### Functional

- `TrainingVolumeDetail`의 `일일 볼륨` stacked bar chart가 현재 period를 초기 visible window로 보여주되, 이전 기간 history까지 수평 스크롤 가능해야 한다.
- `트레이닝 부하` chart는 현재 period의 최신 날짜를 마지막 일자 bin으로 정확히 보여야 한다.
- 두 차트 모두 shared long-press selection overlay contract를 유지해야 한다.

### Non-functional

- 기존 comparison summary, legend, selection UX를 불필요하게 변경하지 않는다.
- bar chart용 x-domain 계산을 공통 helper로 정리해 같은 off-by-one을 다른 일별 bar chart에서도 재발하지 않게 한다.
- UI 제스처 변경은 seeded regression test로 고정한다.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | logic | training volume detail용 scrollable daily history state 추가 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | UI wiring | stacked daily volume chart에 history/period 전달 |
| `DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift` | UI | scrollable stacked bar chart로 확장, visible range/selection wiring 추가 |
| `DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift` | UI | bar chart x-domain 정렬 수정 |
| `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | UI | 동일 bar-domain helper 재사용 여부 정리 |
| `DUNE/Presentation/Shared/Charts/ChartModels.swift` | shared helper | daily bucket bar chart용 x-domain helper 추가 |
| `DUNETests/TrainingVolumeViewModelTests.swift` | test | stacked daily volume history 범위 검증 추가 |
| `DUNETests/ChartModelsTests.swift` or related | test | daily bar domain upper-bound padding 검증 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | test support | training volume daily volume chart AXID 추가 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | UI test | training volume daily volume scroll regression 추가 |

## Implementation Steps

### Step 1: Training Volume History State 분리

- `TrainingVolumeViewModel`에 `chartDailyBreakdown` 상태를 추가한다.
- current + previous period 길이만큼 history range를 계산하고, 이미 fetch한 workouts/manual records로 `buildHistoryDailyBreakdown`을 생성한다.
- summary/comparison은 기존 `PeriodComparison` 계산을 유지하고, chart 전용 history만 별도 상태로 전달한다.

### Step 2: Scrollable Stacked Daily Volume Chart 적용

- `StackedVolumeBarChartView`에 `period`, `scrollPosition`, `visibleRangeLabel`, `ChartUITestSurface`를 추가한다.
- shared `scrollableChartSelectionOverlay`를 scrollable 모드로 연결한다.
- training volume detail 화면에서 기존 `comparison.current.dailyBreakdown` 대신 history용 `chartDailyBreakdown`을 전달한다.

### Step 3: Daily Bucket Bar Domain Alignment 수정

- `ChartModels.swift`에 day-bucket bar chart 전용 x-domain helper를 추가한다.
- 마지막 날짜가 일 단위 bin으로 보일 수 있도록 upper bound를 `last + 1 day`까지 확장한다.
- `TrainingLoadChartView`에 우선 적용하고, 동일 패턴인 `DailyVolumeChartView`/`StackedVolumeBarChartView`도 같은 helper를 사용해 정렬을 통일한다.

### Step 4: Regression Test 보강

- unit test로 training volume chart history의 시작/끝 날짜와 길이를 검증한다.
- unit test로 daily bucket domain helper가 마지막 날짜 다음날까지 upper bound를 확장하는지 검증한다.
- seeded UI test로 `TrainingVolumeDetail` 상단 `일일 볼륨` quick drag 시 visible range가 과거로 바뀌는지 검증한다.

## Testing Strategy

- `scripts/build-ios.sh`
- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/TrainingVolumeViewModelTests -only-testing DUNETests/ChartModelsTests`
- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNEUITests/Regression/ChartInteractionRegressionUITests`

## Risks / Edge Cases

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| history chart legend가 current period exercise type와 어긋날 수 있음 | medium | low | 색상/이름 fallback은 유지하고, current top types 기준 legend를 그대로 둔다 |
| bar-domain helper 변경이 기존 non-scroll 차트에 부작용을 줄 수 있음 | low | medium | scrollable day-bucket chart에만 helper를 적용한다 |
| current day에 데이터가 0이어도 마지막 날짜 bin이 비어 보일 수 있음 | high | low | axis/window 정렬을 테스트로 고정하고, 0-value day도 history 배열에 포함한다 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: stacked daily volume chart는 아직 scroll history 상태가 없어서 수정 경로가 명확하다. training load의 하루 밀림은 bar-domain upper-bound 패턴으로 설명 가능하지만, UI 동작은 seeded test로 실제 확인이 필요하다.
