---
topic: Watch Manual Workout Delete Parity
date: 2026-03-03
status: draft
confidence: medium
related_solutions:
  - docs/solutions/healthkit/2026-02-26-watch-workout-dedup-false-positive.md
related_brainstorms:
  - docs/brainstorms/2026-03-03-watch-manual-workout-delete-parity.md
---

# Implementation Plan: Watch Manual Workout Delete Parity

## Context

워치에서 직접 입력한 운동은 iPhone 앱에서 삭제 시 HealthKit 쪽 데이터가 남아 재표시되거나, HealthKit-only 항목으로 남아 삭제 UI가 제공되지 않는 문제가 있다.
폰 직접 입력 운동과 동일하게 "앱 + HealthKit 동시 삭제" 동작을 보장해야 한다.

## Requirements

### Functional

- 워치 직접입력 운동도 iPhone에서 삭제 가능해야 한다.
- 삭제 시 연결된 HealthKit workout도 함께 삭제되어야 한다.
- `healthKitWorkoutID`가 누락된 레코드라도 가능한 범위에서 HealthKit workout을 찾아 삭제 시도해야 한다.
- HealthKit-only(앱 기원) 운동 항목도 iPhone 목록에서 삭제 가능해야 한다.

### Non-functional

- 기존 폰 입력 운동 삭제 동작 회귀 없어야 한다.
- 삭제 실패 시 사용자 데이터 일관성(앱/HealthKit)이 악화되지 않도록 안전하게 처리한다.
- 기존 dedup 로직과 충돌하지 않아야 한다.

## Approach

삭제 대상 UUID가 있는 경우 기존 UUID 삭제를 유지하고, UUID가 없는 경우 "시간 근접 + 앱 소스" 후보를 조회해 삭제 대상을 복구한다.
또한 HealthKit-only 항목에 삭제 UI를 열어 orphan 상태를 사용자가 직접 정리할 수 있도록 한다.
iPhone 삭제 실패 시 Watch에 삭제 요청을 위임하는 fallback 경로를 추가해 소스 권한 차이 리스크를 낮춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| UUID 없는 레코드는 HealthKit 삭제 포기 | 구현 단순 | 워치 기록 삭제 불가 지속 | 기각 |
| 앱 UI에서만 숨김 처리 | 즉시 UX 개선 | HealthKit 데이터 잔존, 요구사항 미충족 | 기각 |
| UUID 복구 + HealthKit-only 삭제 UI + Watch fallback | 요구사항 충족 가능성 최대 | 구현 범위 증가 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Data/HealthKit/WorkoutDeleteService.swift | update | UUID 누락 시 삭제 대상 workout UUID 복구 로직 추가 |
| DUNE/Data/HealthKit/WorkoutQueryService.swift | update | 앱 패밀리 소스 판정 보강 (watch companion bundle 포함) |
| DUNE/Presentation/Shared/ViewModifiers/ConfirmDeleteRecordModifier.swift | update | UUID 누락 fallback 삭제 + iPhone 실패 시 Watch 삭제 요청 |
| DUNE/Presentation/Exercise/ExerciseView.swift | update | HealthKit-only(앱 소스) 항목 삭제 UI 추가 |
| DUNE/Data/WatchConnectivity/WatchSessionManager.swift | update | iPhone→Watch workout 삭제 요청 전송 경로 추가 |
| DUNEWatch/WatchConnectivityManager.swift | update | Watch에서 삭제 요청 수신 후 HealthKit 삭제 실행 |
| DUNETests/ExerciseViewModelTests.swift | update | watch/manual dedup fallback 회귀 테스트 추가 |
| DUNETests/WorkoutSourceClassifierTests.swift | add | 앱 패밀리 소스 판정 로직 단위 테스트 |

## Implementation Steps

### Step 1: HealthKit 삭제 경로 보강

- **Files**: `WorkoutDeleteService.swift`, `ConfirmDeleteRecordModifier.swift`
- **Changes**:
  - UUID 누락 시 시간 근접 후보를 조회해 삭제 UUID 복구
  - 기존 UUID 삭제 실패 시 Watch 삭제 요청 fallback
- **Verification**:
  - UUID 없는 manual record 삭제 시 HealthKit 삭제 시도 수행
  - UUID 있는 케이스 기존 동작 유지

### Step 2: HealthKit-only 삭제 UX 추가

- **Files**: `ExerciseView.swift`, `WorkoutQueryService.swift`
- **Changes**:
  - 앱 기원 HealthKit row에 swipe delete 제공
  - watch companion bundle을 앱 소스로 인식
- **Verification**:
  - manual / healthKit row 모두 의도한 조건에서 삭제 액션 노출
  - 삭제 후 목록 재로딩 시 항목 제거 확인

### Step 3: Watch fallback 경로 구현

- **Files**: `WatchSessionManager.swift`, `DUNEWatch/WatchConnectivityManager.swift`
- **Changes**:
  - iPhone이 watch로 deletion message/userInfo 전달
  - watch가 HealthKit에서 UUID 삭제 실행
- **Verification**:
  - iPhone 삭제 실패 경로에서 watch fallback 호출 로그 확인

### Step 4: 테스트 보강

- **Files**: `ExerciseViewModelTests.swift`, `WorkoutSourceClassifierTests.swift`
- **Changes**:
  - watch manual dedup fallback 케이스 추가
  - app-family source 판정 함수 테스트 추가
- **Verification**:
  - 신규 테스트 + 기존 관련 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| `healthKitWorkoutID`가 nil | 시간 근접 후보 조회 후 삭제 시도 |
| iPhone HealthKit 삭제 권한/소스 mismatch | Watch 삭제 요청 fallback |
| Watch가 비연결 상태 | `transferUserInfo`로 지연 전달 시도 |
| 동일 시각 workout 다수 | activityType/시간 근접 우선순위로 후보 선택, 미확정 시 미삭제 |

## Testing Strategy

- Unit tests: `ExerciseViewModelTests`, `WorkoutSourceClassifierTests`
- Integration tests: 없음 (HealthKit/WatchConnectivity 실기기 동작은 수동 검증)
- Manual verification:
  - watch 직접 입력 운동 생성 → iPhone에서 삭제
  - 앱 재실행/동기화 후 재등장 여부 확인
  - Health app에서 해당 workout 잔존 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| UUID 복구 후보 오탐 삭제 | low | high | 시간 창 제한 + 앱 소스 필터 + activityType 우선 |
| Watch fallback 전달 지연 | medium | medium | sendMessage + transferUserInfo 병행 |
| UI 삭제 액션 과노출 | low | medium | 앱 소스(`isFromThisApp`) 조건으로 제한 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 삭제 단절 경로(누락 UUID, watch source)를 동시에 보완하지만, HealthKit/WatchConnectivity 실기기 동작은 통합 테스트가 필요하다.
