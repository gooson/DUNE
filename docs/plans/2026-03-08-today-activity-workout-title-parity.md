---
topic: today-activity-workout-title-parity
date: 2026-03-08
status: implemented
confidence: high
related_solutions:
  - docs/solutions/healthkit/2026-03-07-healthkit-workout-title-roundtrip.md
related_brainstorms:
  - docs/brainstorms/2026-02-19-enhanced-workout-display.md
---

# Implementation Plan: Today Activity Workout Title Parity

## Context

투데이탭 활동 섹션의 운동 카드가 앱에서 기록된 HealthKit workout임에도 `"Weight Training"` 같은 generic activity label로 표시된다. 같은 workout을 눌러 상세로 진입하면 `WorkoutSummary.localizedTitle` 기반으로 올바른 운동명이 보이므로, Today card 조립 경로만 display title 우선순위가 어긋난 상태다.

## Requirements

### Functional

- 투데이탭 활동 카드가 HealthKit workout의 stored/custom title을 우선 표시해야 한다.
- legacy activity title은 기존 localized fallback을 유지해야 한다.
- 상세 화면과 Today activity card의 제목이 동일한 우선순위를 사용해야 한다.

### Non-functional

- 기존 Today activity card 정렬/아이콘/metric 계산 로직은 변경하지 않는다.
- 변경 범위는 최소화하고 기존 `WorkoutSummary.localizedTitle` 패턴을 재사용한다.
- 회귀를 막는 단위 테스트를 추가한다.

## Approach

`DashboardViewModel.buildActivityMetrics()`의 per-type card 생성에서 `name`을 `relevantWorkouts.first?.localizedTitle ?? relevantWorkouts.first?.activityType.displayName ?? type`으로 변경한다. 이렇게 하면 이미 Exercise list와 detail에서 검증된 title resolution 경로를 Today activity cards도 공유하게 된다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Dashboard에서 `localizedTitle` 재사용 | 기존 round-trip/fallback 규칙 재사용, 변경 최소 | Today 전용 테스트 추가 필요 | 선택 |
| 새로운 title resolver helper 추가 | 호출부 통일 가능 | 현재는 호출부 1곳만 문제, 추상화 과함 | 보류 |
| HealthMetric 모델에 별도 localizedName 필드 추가 | UI 레이어 확장 여지 | 영향 범위 확대, 요청 대비 과함 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | logic fix | Today activity card title이 HealthKit stored title을 우선 사용하도록 수정 |
| `DUNETests/DashboardViewModelTests.swift` | test | 앱 기록 strength workout 제목 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Align Today card title resolution

- **Files**: `DUNE/Presentation/Dashboard/DashboardViewModel.swift`
- **Changes**: per-type exercise `HealthMetric.name` 구성 시 `WorkoutSummary.localizedTitle`를 최우선으로 사용
- **Verification**: generic strength label 대신 custom workout title이 선택되는지 코드/테스트로 검증

### Step 2: Add regression coverage

- **Files**: `DUNETests/DashboardViewModelTests.swift`
- **Changes**: strength-type HealthKit workout이 Today activity card에서 custom title을 유지하는 테스트 추가
- **Verification**: `swift test` 또는 지정 테스트 실행으로 새 assertion 통과 확인

## Edge Cases

| Case | Handling |
|------|----------|
| metadata title이 비어 있음 | `localizedTitle` 내부 fallback으로 legacy/localized activity name 사용 |
| correction store에 수정 제목이 있음 | `localizedTitle`이 correction store를 우선 반영 |
| 오늘 workout이 없고 과거 workout만 있음 | 동일한 title resolution을 latest historical card에도 적용 |

## Testing Strategy

- Unit tests: `DashboardViewModelTests`에 Today activity title parity 회귀 테스트 추가
- Integration tests: 없음. 화면 진입 자체는 기존 Today regression 범위에 맡김
- Manual verification: Today tab activity section에서 app-recorded strength workout title 확인, 같은 workout detail title과 일치 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| custom title이 원치 않게 다른 운동 타입 카드명으로 노출 | low | medium | `localizedTitle`의 기존 fallback 규칙 재사용, 신규 helper 도입 없이 동일 경로 사용 |
| 테스트가 correction store singleton 상태에 영향받음 | low | low | correction 없는 일반 custom title 케이스로 테스트 구성 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 상세/리스트에서 이미 검증된 title resolution 로직이 있고, Today card만 누락된 단일 호출부라 수정 범위와 리스크가 작다.
