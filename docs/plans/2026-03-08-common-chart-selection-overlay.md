---
topic: common-chart-selection-overlay
date: 2026-03-08
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-02-17-chart-ux-layout-stability.md
  - docs/solutions/architecture/2026-02-23-activity-detail-view-v2-patterns.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-common-chart-selection-overlay.md
---

# Implementation Plan: Common Chart Selection Overlay

## Context

공통 차트 컴포넌트의 선택 UX는 현재 `chartXSelection` + 상단 고정형 `ChartSelectionOverlay`에 의존한다. 이 방식은 레이아웃 시프트는 막았지만, 실제 사용 중에는 손가락 위치와 선택 포인트가 어긋나 보이고, 날짜/값 정보가 차트 상단에 고정되어 포인트와 시각적으로 분리된다.

이번 변경은 shared chart layer에서 선택 제스처와 오버레이 배치를 함께 재설계해, BMI를 포함한 공통 차트 전체에 동일한 드래그 정확도와 근접 오버레이 UX를 제공하는 것이 목적이다.

## Requirements

### Functional

- 롱프레스 후 좌우 드래그 시 선택 포인트가 손가락 위치와 자연스럽게 대응해야 한다.
- 선택 정보 오버레이는 선택 포인트 근처에 표시되어야 한다.
- 좌우 끝점에서는 오버레이가 카드 밖으로 나가지 않도록 clamp 되어야 한다.
- 상단 공간이 부족하면 오버레이를 포인트 아래로 뒤집어 배치해야 한다.
- `AreaLine`, `DotLine`, `Bar`, `RangeBar`, `HeartRate`, `SleepStage`의 selection UI를 공통 방식으로 맞춰야 한다.
- `week`, `month`, `sixMonths`, `year` 등 스크롤 가능한 기간에서도 selection이 일관되어야 한다.

### Non-functional

- 차트 레이아웃 높이와 기존 glass styling은 유지해야 한다.
- trend line, axis, accessibility descriptor, scroll position 동작을 깨뜨리면 안 된다.
- 공통 수학/배치 로직은 순수 함수로 분리해 테스트 가능해야 한다.
- 선택 없는 차트(`MiniSparklineView`, `HeartRateZoneChartView`)에는 불필요한 복잡성을 추가하지 않는다.

## Approach

Swift Charts selection을 기본 `chartXSelection`에서 `chartOverlay + ChartProxy + GeometryReader` 기반 직접 제어로 옮긴다. 터치 x 좌표를 plot area 기준으로 정규화해 `Date`를 얻고, 실제 데이터 배열에서 가장 가까운 포인트로 snap 한다. 그 다음 `ChartProxy.position(forX:y:)`로 선택 포인트 anchor를 계산하고, 공통 배치 함수가 오버레이의 최종 위치와 위/아래 방향을 결정한다.

공통 배치 계산은 shared helper로 추출하고, 각 차트는 자신의 데이터 타입(`ChartDataPoint`, `RangeDataPoint`, `HeartRateSample`, `StackedDataPoint`)에 맞는 선택 포인트와 시각적 mark만 담당한다.

Apple의 Swift Charts interaction 패턴(`chartOverlay`, `ChartProxy`, plot area 기반 interaction)은 WWDC 2022 Swift Charts 세션의 공식 예시와 동일한 방향으로 적용한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 `chartXSelection` 유지 + overlay만 floating으로 변경 | 수정 범위가 작음 | 손가락-선택점 어긋남 문제를 근본 해결하지 못함 | 기각 |
| 차트별 개별 gesture 구현 | 각 차트에 맞춘 세밀한 제어 가능 | 중복 증가, 유지보수 어려움, 공통 UX 일관성 저하 | 기각 |
| 공통 helper + 차트별 포인트 매핑 | 재사용성, 테스트 가능성, 일관된 UX | 초기 설계 비용이 있음 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | modify | 상단 고정형 overlay를 floating annotation 형태로 확장 |
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | add | 공통 selection state, anchor 계산, clamp 배치 helper 추가 |
| `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift` | modify | 직접 gesture selection + floating overlay 적용 |
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | modify | 직접 gesture selection + floating overlay 적용 |
| `DUNE/Presentation/Shared/Charts/BarChartView.swift` | modify | 직접 gesture selection + floating overlay 적용 |
| `DUNE/Presentation/Shared/Charts/RangeBarChartView.swift` | modify | 직접 gesture selection + floating overlay 적용 |
| `DUNE/Presentation/Shared/Charts/HeartRateChartView.swift` | modify | 운동 세션 심박 차트에도 동일 selection 패턴 적용 |
| `DUNE/Presentation/Shared/Charts/SleepStageChartView.swift` | modify | stacked sleep chart selection header를 floating overlay로 전환 |
| `DUNETests/ChartSelectionInteractionTests.swift` | add | clamp/orientation/snap math 회귀 테스트 추가 |

## Implementation Steps

### Step 1: 공통 selection 모델과 overlay 배치 helper 도입

- **Files**: `ChartSelectionOverlay.swift`, `ChartSelectionInteraction.swift`
- **Changes**:
  - floating overlay의 앵커/방향/offset을 표현하는 공통 타입 추가
  - 카드 경계 내부 clamp, 위/아래 반전, anchor fallback 수학을 순수 함수로 분리
  - 기존 overlay 스타일은 유지하되, 위치를 외부에서 제어할 수 있도록 변경
- **Verification**:
  - helper가 SwiftUI 의존 없이 컴파일됨
  - 오버레이 배치 수학을 단위 테스트 대상으로 노출함

### Step 2: line/area/bar/range 공통 차트 selection을 직접 gesture 기반으로 전환

- **Files**: `AreaLineChartView.swift`, `DotLineChartView.swift`, `BarChartView.swift`, `RangeBarChartView.swift`
- **Changes**:
  - `chartXSelection` 제거 또는 보조 역할 축소
  - `chartOverlay` 내부에서 long press + drag gesture를 사용해 plot area 기준 선택 계산
  - nearest-date snap과 selected anchor 계산을 helper로 연결
  - 오버레이를 포인트 근처에 absolute 배치
- **Verification**:
  - 각 차트가 기존 mark styling을 유지한 채 선택 indicator와 overlay를 표시함
  - 스크롤 가능한 기간에서 선택 후 드래그가 정상 동작함

### Step 3: HeartRate/SleepStage 차트까지 selection UX 일관성 확장

- **Files**: `HeartRateChartView.swift`, `SleepStageChartView.swift`
- **Changes**:
  - 심박 시계열 차트에 동일한 직접 선택/overlay 배치 적용
  - stacked sleep chart의 상단 header를 floating overlay로 대체
  - day-only sleep timeline은 selection UX가 없으므로 유지, stacked bar mode만 개선
- **Verification**:
  - 운동 상세의 심박 차트와 sleep stacked 차트가 동일한 interaction 패턴을 가짐
  - 사용되지 않는 day timeline 모드는 회귀 없이 유지됨

### Step 4: 공통 수학 테스트 및 빌드/테스트 검증

- **Files**: `DUNETests/ChartSelectionInteractionTests.swift`
- **Changes**:
  - 좌/우 clamp
  - 상/하 반전
  - 중앙 정렬 유지
  - nearest-date snap 또는 anchor fallback 계산 테스트 추가
- **Verification**:
  - `xcodebuild test`로 신규 테스트 통과
  - 관련 타겟 build/test 결과 확보

## Edge Cases

| Case | Handling |
|------|----------|
| 첫/마지막 포인트 선택 | overlay x 위치를 card padding 내부로 clamp |
| 최고점에서 overlay 상단 잘림 | 위 공간 부족 시 아래 배치로 반전 |
| 최저점에서 x축 라벨과 충돌 | 아래 배치 마진을 두고, 불가 시 위 배치 유지 |
| 평평한 선 그래프 | selected point + rule mark를 유지해 선택 지점 식별성 확보 |
| 주/월 집계 버킷 selection | proxy가 반환한 date를 실제 집계 포인트 배열에 nearest snap |
| 수평 스크롤 직후 interaction | plot area origin 기준 좌표 계산으로 scroll offset과 분리 |
| sleep day timeline | 현재 selection UX가 없으므로 이번 변경 범위에서 제외, stacked mode만 적용 |

## Testing Strategy

- Unit tests:
  - `ChartSelectionInteractionTests`에서 overlay clamp/orientation/anchor math를 검증
  - nearest snap helper가 예상 포인트를 선택하는지 검증
- Integration tests:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests -quiet`
- Manual verification:
  - BMI/Weight detail에서 week/month/6M/year drag 확인
  - RHR range bar와 Steps/Sleep bar chart selection 확인
  - Exercise/Workout detail의 heart rate chart 확인
  - 오버레이가 좌우 끝점과 상단/하단 경계에서 카드 밖으로 나가지 않는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `ChartProxy.position(forX:y:)` 좌표 계산이 차트 유형마다 다르게 동작 | Medium | High | 공통 helper는 배치만 담당하고, 각 차트에서 anchor 계산을 명시적으로 조정 |
| long press + drag gesture가 chart scroll과 충돌 | Medium | High | 롱프레스 시작 후에만 selection drag를 활성화하고, 실제 차트 스크롤과 우선순위를 실기기/시뮬레이터로 확인 |
| floating overlay가 axis/legend와 겹침 | Medium | Medium | clamp margin과 vertical fallback 규칙을 helper로 통일 |
| helper 추상화가 과해져 차트별 커스터마이징이 어려워짐 | Low | Medium | 공통화 범위는 gesture/snap/layout으로 제한하고 mark rendering은 각 차트에 남김 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 shared chart들의 selection 구조가 거의 동일하고, 공식 Swift Charts interaction 패턴과도 맞는다. 공통 수학을 순수 함수로 분리하면 UI 변경 범위 대비 회귀 위험을 낮출 수 있다.
