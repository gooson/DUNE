---
topic: non-distance-cardio-level-model
date: 2026-03-07
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-02-28-cardio-secondary-unit-pattern.md
  - docs/solutions/architecture/2026-03-02-ios-cardio-live-tracking.md
  - docs/solutions/general/2026-03-02-phone-watch-cardio-parity.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-non-distance-cardio-level-model.md
  - docs/brainstorms/2026-03-03-stair-climber-flights-tracking.md
---

# Implementation Plan: Non-Distance Cardio Level Model

## Context

Stair Climber와 Elliptical 같은 비거리 유산소가 여전히 distance/sets 중심 흐름의 영향을 받는다.
그 결과 Stair Climber는 세트 기반 입력 화면으로 빠질 수 있고, Watch cardio 세션에서도 머신의 핵심 입력인 `level`이 존재하지 않는다.
이번 변경의 목표는 비거리 유산소를 `watch-first cardio session`으로 통일하고, 시간은 자동 측정하며, 머신 강도는 `level`로 입력하도록 재모델링하는 것이다.

## Requirements

### Functional

- `durationDistance` 운동 중 비거리 유산소도 cardio session으로 진입해야 한다
- Stair Climber / Elliptical 같은 머신 유산소는 outdoor 선택이 아니라 indoor cardio session으로 시작해야 한다
- cardio session 중 machine `level`을 입력/조정할 수 있어야 한다
- iPhone cardio session의 칼로리 추정은 level 기반으로 조정되어야 한다
- Watch/iPhone cardio 요약 및 저장 레코드에 평균/최대 level 정보가 반영되어야 한다
- Stair Climber의 수동 `floors` 입력 UX는 시작 흐름에서 제거되어야 한다

### Non-functional

- 기존 exercise library / `durationDistance` 구조를 유지해 CloudKit/JSON 호환을 깨지 않는다
- SwiftData는 lightweight migration으로 확장한다
- Watch/iOS 공통 모델은 단일 소스를 유지한다
- 기존 distance-based cardio UX와 테스트를 깨지 않는다

## Approach

`ExerciseInputType`는 그대로 `durationDistance`를 유지하고, cardio session 분기/표시 로직을 `distance-based`가 아니라 `durationDistance + cardio unit` 기준으로 재정의한다.

핵심 변경은 세 가지다.

1. `WorkoutActivityType.resolveCardioActivity(...)`를 추가해 Stair Climber/Elliptical도 cardio session 후보로 인식
2. Watch `WorkoutMode`와 iPhone `CardioSessionViewModel`에 machine-level tracking 상태를 추가
3. `ExerciseRecord`에 optional level summary 필드를 추가해 cardio-centric history/detail을 유지

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 새 inputType (`durationLevel`) 도입 | 의미가 명확함 | exercise JSON, custom exercise, watch sync, UI 전체 파급이 큼 | 기각 |
| 기존 `WorkoutSet.intensity` 재사용 | 스키마 변경 없음 | cardio에 set semantics가 새고 사용자 요구와 정면 충돌 | 기각 |
| `durationDistance` 유지 + cardio session/unit 로직 확장 | 기존 데이터 구조 보존, 변경 범위가 집중됨 | 일부 session UI/WorkoutMode 확장이 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/WorkoutActivityType.swift` | Edit | non-distance cardio용 generalized resolver 추가 |
| `DUNE/Domain/Models/WorkoutMode.swift` | Edit | cardio mode에 secondary unit 보존 |
| `DUNE/Domain/Models/CardioSecondaryUnit.swift` | Edit | machine level 지원 메타데이터 추가 |
| `DUNE/Data/Persistence/Models/ExerciseRecord.swift` | Edit | cardio machine level summary 필드 추가 |
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | Edit | V11 lightweight migration 추가 |
| `DUNE/Presentation/Exercise/ExerciseStartView.swift` | Edit | 모든 cardio session 후보를 CardioStartSheet로 라우팅 |
| `DUNE/Presentation/Exercise/CardioSession/CardioStartSheet.swift` | Edit | machine cardio indoor-only 시작 UX |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionViewModel.swift` | Edit | machine level tracking + level-based calorie estimation |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionView.swift` | Edit | level control / machine-cardio metric UI |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | Edit | avg/max level 요약 및 저장 반영 |
| `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift` | Edit | 저장된 cardio machine level 표시 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | Edit | non-distance cardio도 preview에서 cardio flow로 시작 |
| `DUNEWatch/Managers/WorkoutManager.swift` | Edit | secondary unit + level tracking 상태/저장 |
| `DUNEWatch/Views/Cardio/CardioMainMetricsPage.swift` | Edit | machine cardio live level 표시 |
| `DUNEWatch/Views/Cardio/CardioSecondaryPage.swift` | Edit | machine cardio level control / avg/max level 표시 |
| `DUNEWatch/Views/SessionSummaryView.swift` | Edit | machine cardio level 저장 및 요약 표시 |
| `DUNETests/CardioWorkoutModeTests.swift` | Edit | generalized cardio resolver / WorkoutMode roundtrip 테스트 |
| `DUNETests/CardioSecondaryUnitTests.swift` | Edit | machine level metadata 테스트 |
| `DUNETests/CardioSessionViewModelTests.swift` | Edit | level tracking / non-distance distance visibility / calorie adjustment 테스트 |

## Implementation Steps

### Step 1: Domain/session routing 기반 정리

- **Files**: `WorkoutActivityType.swift`, `WorkoutMode.swift`, `CardioSecondaryUnit.swift`, `ExerciseStartView.swift`, `WorkoutPreviewView.swift`, `CardioStartSheet.swift`
- **Changes**:
  - `resolveCardioActivity` 추가
  - cardio `WorkoutMode`가 `secondaryUnit`을 보존하도록 확장
  - machine-cardio 판단용 metadata (`supportsMachineLevel`, indoor-only 여부, level range) 추가
  - iPhone/Watch 시작 플로우가 Stair Climber/Elliptical을 cardio session으로 라우팅
  - machine cardio는 indoor-only UX로 단순화
- **Verification**:
  - resolver/unit tests 통과
  - Stair Climber/Elliptical이 세트 입력이 아닌 cardio flow 후보로 분기됨

### Step 2: iPhone cardio session에 level tracking 추가

- **Files**: `CardioSessionViewModel.swift`, `CardioSessionView.swift`, `CardioSessionSummaryView.swift`
- **Changes**:
  - current/average/max level state 추가
  - time-weighted level 기반 MET 평균 계산
  - distance 카드 숨김 여부를 `cardioSecondaryUnit` 기준으로 전환
  - non-distance cardio summary에 avg/max level 표시 및 저장 반영
- **Verification**:
  - Stair/elliptical에서 distance 숨김
  - level 변경에 따라 estimatedCalories 또는 summary 값이 달라짐
  - `CardioSessionViewModelTests` 신규 케이스 통과

### Step 3: Watch cardio session에 level tracking 추가

- **Files**: `WorkoutManager.swift`, `CardioMainMetricsPage.swift`, `CardioSecondaryPage.swift`, `SessionSummaryView.swift`
- **Changes**:
  - watch cardio mode가 secondary unit + level state를 유지
  - machine cardio 세션에서 live/current level, avg/max level 표시
  - summary 저장 시 level summary를 `ExerciseRecord`에 기록
- **Verification**:
  - Watch cardio mode roundtrip/codable 테스트 통과
  - machine cardio summary에 avg/max level이 나타남

### Step 4: Persistence/detail/test 마감

- **Files**: `ExerciseRecord.swift`, `AppSchemaVersions.swift`, `ExerciseSessionDetailView.swift`, 관련 테스트 파일
- **Changes**:
  - `ExerciseRecord`에 optional machine-level 필드 추가
  - V11 lightweight migration 추가
  - detail/history에서 cardio machine level 노출
  - 회귀 테스트 보강
- **Verification**:
  - build/test 통과
  - 기존 ExerciseRecord init callsite가 깨지지 않음
  - 저장된 cardio record 상세에서 level 확인 가능

## Edge Cases

| Case | Handling |
|------|----------|
| level을 한 번도 입력하지 않은 세션 | level summary는 nil, 칼로리 추정은 base MET fallback |
| session 중 pause/resume | paused 구간은 level time weighting에서 제외 |
| Stair Climber는 floors가 자동 수집되지만 사용자가 입력 안 함 | floors는 보조 metric으로만 저장/표시 |
| Elliptical은 activity type상 distance-based로 분류되어 있음 | session UI의 distance 노출은 `cardioSecondaryUnit` 기준으로 override |
| Watch workout recovery/serialization | `WorkoutMode` codable 변경을 테스트로 고정 |

## Testing Strategy

- Unit tests:
  - `CardioWorkoutModeTests`에 generalized cardio resolver / new `WorkoutMode.cardio` roundtrip 추가
  - `CardioSecondaryUnitTests`에 machine-level metadata assertions 추가
  - `CardioSessionViewModelTests`에 level tracking, calorie adjustment, distance visibility tests 추가
- Integration tests:
  - `scripts/test-unit.sh --ios-only`
  - `scripts/test-unit.sh --watch-only`
- Manual verification:
  - iPhone에서 Stair Climber 시작 → cardio summary로 저장되는지
  - Watch에서 Stair Climber/Elliptical 시작 → indoor session + level 조절 + summary 저장되는지

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `WorkoutMode` case 변경으로 watch recovery/codable 회귀 | Medium | High | dedicated unit test + recovery state roundtrip 확인 |
| SwiftData field 추가로 migration/CloudKit mismatch | Medium | High | optional field only + V11 lightweight migration |
| Elliptical distance UI 변경이 기존 기대와 충돌 | Medium | Medium | session UI만 `cardioSecondaryUnit` 기준으로 override, activity type 자체는 유지 |
| level-based calorie formula가 과도하게 변동 | Medium | Medium | 기존 stair multiplier를 기반으로 보수적 재사용, tests로 경계값 고정 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 cardio infrastructure와 cardioSecondaryUnit 패턴이 이미 있어 설계 방향은 명확하다. 다만 watch `WorkoutMode` 확장과 SwiftData migration이 걸려 있어 회귀 가능성은 중간 수준이다.
