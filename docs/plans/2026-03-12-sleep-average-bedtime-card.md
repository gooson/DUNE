---
topic: sleep-average-bedtime-card
date: 2026-03-12
status: approved
confidence: high
related_solutions:
  - docs/solutions/architecture/sleep-deficit-personal-average.md
  - docs/solutions/general/2026-03-08-general-bedtime-reminder.md
  - docs/solutions/healthkit/2026-03-11-sleep-all-data-time-anchor.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-sleep-deficit-personal-average.md
  - docs/brainstorms/2026-03-08-general-bedtime-reminder.md
---

# Implementation Plan: Sleep Average Bedtime Card

## Context

수면 상세 화면은 차트 아래에 `Sleep Debt` 카드만 노출하고 있다. 사용자는 최근 수면을 시작하는 시간의 평균을 한눈에 보고 싶어 하며, 현재 코드베이스에는 이를 계산하는 `CalculateAverageBedtimeUseCase`가 이미 존재한다. 따라서 기존 계산 로직을 재사용해 수면 부채 카드 바로 위에 평균 취침 시간 카드를 추가하는 것이 가장 일관적이다.

## Requirements

### Functional

- 수면 상세 화면에서 `Sleep Debt` 카드 바로 위에 `Average Bedtime` 카드를 노출한다.
- 카드는 최근 수면 시작 시각의 평균을 보여준다.
- 평균 시각이 계산되지 않으면 카드를 숨긴다.
- 평균 계산은 자정 전후 취침을 안정적으로 처리해야 한다.

### Non-functional

- 기존 수면 부채/차트 로딩 흐름을 깨지 않는다.
- 기존 `CalculateAverageBedtimeUseCase`를 재사용해 중복 계산 로직을 만들지 않는다.
- 사용자 대면 문자열은 `Localizable.xcstrings`에 en/ko/ja를 함께 추가한다.
- 새 로직은 `MetricDetailViewModelTests`로 회귀를 보호한다.

## Approach

수면 detail 전용 보조 상태를 `MetricDetailViewModel`에 추가한다. 수면 데이터를 로드할 때 최근 7일 수면 stage를 병렬 조회하고, 기존 `CalculateAverageBedtimeUseCase`로 평균 취침 시각을 계산해 저장한다. View는 이 상태가 있을 때만 `StandardCard` 기반의 새 `AverageBedtimeCard`를 렌더링한다. 시간 표시는 Foundation의 localized hour/minute formatting 패턴을 사용해 locale에 맞게 출력한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `MetricDetailView`에서 직접 7일 수면 조회 | 구현이 직관적 | View에 비동기 데이터 로직이 스며들고 테스트가 어려움 | 기각 |
| 기존 `BedtimeReminderScheduler` 결과 재사용 | 7일 평균 기준과 동일 | UI가 scheduler 수명주기에 간접 의존하고 detail 진입 시 최신성이 불명확함 | 기각 |
| `MetricDetailViewModel`에서 use case 직접 재사용 | 현 구조와 일관적, 테스트 용이, 최신 데이터 기준 | sleep detail 전용 상태가 하나 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | modify | 평균 취침 시간 상태/로딩 로직 추가 |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | modify | 수면 부채 카드 위에 새 카드 삽입 |
| `DUNE/Presentation/Sleep/AverageBedtimeCard.swift` | add | 평균 취침 시간 카드 UI 컴포넌트 |
| `DUNETests/MetricDetailViewModelTests.swift` | modify | 평균 취침 시간 계산/노출 회귀 테스트 추가 |
| `Shared/Resources/Localizable.xcstrings` | modify | `Average Bedtime` 및 필요 보조 문자열 번역 추가 |

## Implementation Steps

### Step 1: Sleep detail state 확장

- **Files**: `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift`
- **Changes**: 최근 7일 수면 stage 조회, `CalculateAverageBedtimeUseCase` 실행, 화면용 평균 취침 시간 상태 저장
- **Verification**: sleep detail load 후 평균 취침 시간 상태가 비어 있지 않은 시나리오를 테스트에서 확인

### Step 2: 평균 취침 시간 카드 UI 추가

- **Files**: `DUNE/Presentation/Shared/Detail/MetricDetailView.swift`, `DUNE/Presentation/Sleep/AverageBedtimeCard.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**: 수면 부채 카드 위에 새 카드 배치, locale-aware 시간 표시, 번역 문자열 추가
- **Verification**: sleep category에서만 카드가 보이고, 평균값이 없으면 렌더링되지 않음을 코드 경로로 확인

### Step 3: 테스트 보강

- **Files**: `DUNETests/MetricDetailViewModelTests.swift`
- **Changes**: 자정 전후 데이터가 섞인 최근 7일 stage 입력으로 평균 취침 시간이 계산되는지 검증
- **Verification**: `swift test` 또는 `xcodebuild test`로 신규 테스트 통과 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 최근 수면 데이터가 없는 경우 | average bedtime state를 `nil`로 두고 카드 미표시 |
| 깨어 있음(`awake`)만 있는 날 | 기존 use case 동작대로 계산에서 제외 |
| 23시대와 0시대 취침이 섞인 경우 | 기존 circular averaging 로직 재사용 |
| locale별 12/24시간 표시 차이 | localized time formatting 사용 |

## Testing Strategy

- Unit tests: `MetricDetailViewModelTests`에 sleep detail 평균 취침 시간 상태 검증 추가
- Integration tests: 없음. 기존 detail screen 조합 로직 범위 내
- Manual verification: 수면 상세 화면에서 `Average Bedtime` 카드가 `Sleep Debt` 위에 나타나는지, 시간이 locale에 맞게 표시되는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 7일 stage 추가 조회로 sleep detail 로드가 느려질 수 있음 | medium | medium | 병렬 조회 유지, 조회 범위를 7일로 제한 |
| 카드 표시 기준이 sleep debt와 달라 UX가 어색할 수 있음 | low | medium | recent 7-night bedtime 기준을 명시적 카드 제목으로 노출 |
| `xcstrings` 수동 편집 실수 | medium | low | 기존 JSON 구조를 그대로 따라 최소 키만 추가 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 평균 취침 시간 계산 use case와 7일 lookup 패턴이 이미 코드베이스에 존재해 신규 설계 리스크가 낮다.
