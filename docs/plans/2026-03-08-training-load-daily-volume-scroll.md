---
topic: training-load-daily-volume-scroll
date: 2026-03-08
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-08-chart-long-press-scroll-regression.md
  - docs/solutions/general/2026-03-08-common-chart-selection-overlay.md
  - docs/solutions/architecture/2026-03-08-chart-scroll-unified-vitals.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-chart-scroll-common-logic.md
---

# Implementation Plan: Training Load And Daily Volume Scroll

## Context

트레이닝부하(`TrainingLoadChartView`)와 주간 통계의 일일 볼륨(`DailyVolumeChartView`) 차트는 공통 selection overlay는 이미 사용하지만, 현재 visible window 바깥의 히스토리 데이터와 scroll state를 갖지 않아 과거 데이터로 이동할 수 없다. 이 프로젝트의 최근 차트 수정 패턴상, 스크롤 가능 차트는 다음 3가지를 모두 충족해야 한다.

1. visible window 밖까지 포함하는 히스토리 데이터
2. 차트 domain/scroll position으로 초기 window와 과거 범위가 공존하는 상태
3. seeded UI regression으로 quick drag + long press lifecycle 고정

## Requirements

### Functional

- Training Volume detail의 트레이닝부하 차트가 현재 period를 초기 window로 보여주되, 이전 기간 데이터로 수평 스크롤 가능해야 한다.
- Weekly Stats detail의 일일 볼륨 차트가 현재 period를 초기 window로 보여주되, 이전 기간 데이터로 수평 스크롤 가능해야 한다.
- scrollable chart에서도 기존 long-press selection overlay contract를 유지해야 한다.
- Weekly Stats `lastWeek`처럼 현재 시점이 아닌 구간도 chart history range 기준으로 과거 데이터를 볼 수 있어야 한다.

### Non-functional

- 최근 공통 차트 해결책(`scrollableChartSelectionOverlay`)을 재사용한다.
- 기존 summary/comparison UI 동작을 불필요하게 바꾸지 않는다.
- seeded/mock UI 테스트로 제스처 회귀를 막는다.

## Approach

두 차트를 모두 "현재 window만 가진 정적 차트"에서 "히스토리 데이터 + 초기 visible window가 있는 scrollable 차트"로 전환한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 차트에 `chartScrollableAxes`만 추가 | 변경량이 작음 | 히스토리 데이터가 없으면 실제 스크롤 불가 | 기각 |
| 각 화면에서 로컬 gesture patch 추가 | 빠르게 보일 수 있음 | 최근 공통 overlay/gesture contract를 다시 깨뜨림 | 기각 |
| 뷰모델에서 히스토리 범위를 만들고 차트는 shared overlay + scroll state만 담당 | 기존 해결책과 정합성 높음 | 상태/테스트 파일이 몇 개 더 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | logic | selected period 기반 training load history fetch로 확대 |
| `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailViewModel.swift` | logic | chart history daily breakdown 상태 추가 및 range-based fetch 정리 |
| `DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift` | UI | scroll position, visible range label, selection probe, scrollable overlay 적용 |
| `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | UI | scroll position, visible range label, scrollable overlay 적용 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | UI wiring | period를 training load chart에 전달하고 식별자 연결 |
| `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift` | UI wiring | history breakdown/period를 daily volume chart에 전달하고 식별자 연결 |
| `DUNE/Presentation/Shared/Extensions/VolumePeriod+View.swift` | presentation helper | visible domain/label/axis stride 등 period presentation helper 추가 |
| `DUNE/Domain/UseCases/TrainingVolumeAnalysisService.swift` | shared logic | daily breakdown history를 view model에서 재사용할 수 있도록 공개 helper 추가 검토 |
| `DUNETests/TrainingVolumeViewModelTests.swift` | test | training load history 범위 검증 |
| `DUNETests/WeeklyStatsDetailViewModelTests.swift` | test | chart history breakdown 범위 검증 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | test support | 새 chart/visible range identifier 추가 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | UI test | Training Load / Weekly Stats scroll regression 추가 |

## Implementation Steps

### Step 1: History Range And ViewModel Data

- **Files**: `TrainingVolumeViewModel.swift`, `WeeklyStatsDetailViewModel.swift`, `TrainingVolumeAnalysisService.swift`
- **Changes**:
  - Training Volume detail은 `selectedPeriod.days * 2` 범위의 training load history를 가져오도록 바꾼다.
  - Weekly Stats detail은 `StatsPeriod.fetchDays`와 `dateRange.end`를 기준으로 chart history range를 만들고, 그 범위의 `DailyVolumePoint` 배열을 별도 상태로 유지한다.
  - 필요하면 `TrainingVolumeAnalysisService`의 daily breakdown builder를 뷰모델에서 재사용 가능한 형태로 노출한다.
- **Verification**:
  - unit test로 history 배열 길이와 끝 날짜가 기대값과 일치하는지 확인한다.

### Step 2: Scrollable Chart Wiring

- **Files**: `TrainingLoadChartView.swift`, `DailyVolumeChartView.swift`, `VolumePeriod+View.swift`, `TrainingVolumeDetailView.swift`, `WeeklyStatsDetailView.swift`
- **Changes**:
  - 두 차트에 internal `scrollPosition`과 explicit x-domain을 추가한다.
  - period별 visible domain length, 초기 scroll 위치, visible range label, axis stride를 공통 helper로 맞춘다.
  - 기존 long-press selection overlay contract는 유지하고, selection probe/visible range identifier를 노출한다.
- **Verification**:
  - seeded UI test에서 quick drag 시 visible range가 바뀌는지 확인한다.
  - long press 시 selection probe가 활성화되지만 visible range는 유지되는지 확인한다.

### Step 3: Regression Coverage And Quality Check

- **Files**: `TrainingVolumeViewModelTests.swift`, `WeeklyStatsDetailViewModelTests.swift`, `UITestHelpers.swift`, `ChartInteractionRegressionUITests.swift`
- **Changes**:
  - view model unit tests를 추가/보강한다.
  - 새 chart accessibility id/visible range id를 AXID에 추가한다.
  - Weekly Stats 및 Training Volume detail에 대한 scroll regression을 추가한다.
- **Verification**:
  - `swift test` 또는 `xcodebuild test`로 unit test 실행
  - `xcodebuild test`로 해당 UI regression 실행

## Edge Cases

| Case | Handling |
|------|----------|
| selected period보다 히스토리 데이터가 적음 | chart domain을 실제 data range로 클램프하고 스크롤은 비활성화 |
| `lastWeek`처럼 현재 시점이 아닌 구간 | history range end를 `dateRange.end`로 맞춰 현재 window가 올바른 주간에 위치하도록 처리 |
| 빈 일자 다수 포함 | daily breakdown/training load를 0 값으로 채워 scroll domain을 유지 |
| long press 후 바로 scroll | shared `scrollableChartSelectionOverlay` cleanup contract 유지 |

## Testing Strategy

- Unit tests: Training Volume / Weekly Stats view model의 history data range 계산과 상태 반영 검증
- UI tests: Training Load / Weekly Stats chart quick drag scroll, long press selection probe, visible range stability
- Manual verification: Activity > Training Volume, Activity > Weekly Stats에서 현재 window 시작값과 과거 스크롤 동작 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| scrollPosition 초기값이 하루 오프셋으로 밀릴 수 있음 | medium | medium | start-of-day 기준으로 초기 window 계산, visible range probe로 UI test 고정 |
| Weekly Stats `lastWeek` 기존 비교 로직과 chart history 범위가 어긋날 수 있음 | medium | medium | summary 로직은 건드리지 않고 chart history 범위만 별도 상태로 유지 |
| 3M/6M training load에서 축 라벨이 과밀해질 수 있음 | medium | low | period별 stride helper 추가 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 공통 overlay/scroll 해결책과 range-based fetch 선례가 이미 있어 구현 방향은 명확하다. 다만 Weekly Stats의 `lastWeek`가 현재도 특수 케이스를 갖고 있어 chart history 상태를 summary와 분리하는 부분은 검증이 필요하다.
