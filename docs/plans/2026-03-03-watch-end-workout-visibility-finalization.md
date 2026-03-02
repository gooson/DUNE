---
topic: watch-end-workout-visibility-finalization
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-02-watchos-button-overflow-fix.md
  - docs/solutions/general/2026-03-02-watch-workout-start-timeout-guard.md
related_brainstorms: []
---

# Implementation Plan: Watch End Workout Visibility + Finalization Reliability

## Context

watchOS 시뮬레이터에서 운동 종료 확인 다이얼로그의 종료 버튼이 잘 보이지 않고, 탭 후에도 종료가 되지 않는 것처럼 보이는 문제가 있었다. UI 가시성과 HealthKit 종료 콜백 안정성을 동시에 보강해야 한다.

## Requirements

### Functional

- 종료 확인 다이얼로그에서 `End Workout` 액션이 명확히 보인다.
- `End Workout` 탭 직후 세션이 종료 플로우로 전환된다.
- HealthKit 종료 delegate 콜백이 지연/누락되어도 종료 UX가 멈추지 않는다.
- `workoutEnded` WatchConnectivity 신호는 중복 없이 1회만 전송된다.

### Non-functional

- Watch/iOS 기존 저장 플로우(요약 화면 저장, reset 경로)를 깨지 않는다.
- stale delegate 콜백으로 현재 세션 상태가 오염되지 않도록 방어한다.
- 워치 타깃 빌드/테스트를 통과한다.

## Approach

종료 버튼 role을 기본 버튼으로 바꿔 대비를 회복하고, `WorkoutManager.end()`에서 즉시 `isSessionEnded`를 전환해 사용자 체감 종료를 보장한다. 동시에 finalization watchdog과 session identity guard를 추가해 simulator 불안정 구간을 방어한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `.destructive` 유지 + 색상 토큰만 변경 | 코드 변경 작음 | 시스템 다이얼로그 렌더링에서 재발 가능 | 미선택 |
| delegate 콜백만 신뢰하고 UI 대기 | 구현 단순 | simulator에서 종료 무반응 재발 | 미선택 |
| 즉시 상태 전환 + watchdog + 중복 알림 가드 | 사용자 체감 안정성 높음 | 상태 관리 코드 증가 | 선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Managers/WorkoutManager.swift` | 수정 | 즉시 종료 전환, finalize watchdog, stale callback 방어, ended 알림 단일화 |
| `DUNEWatch/Views/CardioMetricsView.swift` | 수정 | 종료 확인 버튼 role 조정 |
| `DUNEWatch/Views/MetricsView.swift` | 수정 | 종료 확인 버튼 role 조정 |
| `DUNEWatch/Views/ControlsView.swift` | 수정 | 종료 확인 버튼 role 조정 |
| `docs/solutions/general/2026-03-03-watch-end-workout-visibility-and-finalization.md` | 추가 | 문제/해결/예방 문서화 |
| `CLAUDE.md` | 수정 | correction log 항목 추가 |

## Implementation Steps

### Step 1: 종료 액션 안정화

- **Files**: `WorkoutManager.swift`
- **Changes**: `end()`에서 `isSessionEnded` 즉시 전환, finalization timeout watchdog 추가, `workoutEnded` 전송 1회 가드
- **Verification**: 종료 탭 직후 Summary 진입, finalize 대기 중에도 Done 버튼 deadlock 없음

### Step 2: delegate 안전성 보강

- **Files**: `WorkoutManager.swift`
- **Changes**: delegate 콜백에서 현재 `session`과 identity 일치 검증, failure 시 finalize 상태 정리
- **Verification**: stale callback이 현재 세션 상태를 변경하지 않음

### Step 3: 종료 다이얼로그 가시성 수정

- **Files**: `CardioMetricsView.swift`, `MetricsView.swift`, `ControlsView.swift`
- **Changes**: `Button("End Workout", role: .destructive)` -> `Button("End Workout")`
- **Verification**: 종료 버튼 대비/가독성 개선

### Step 4: 품질 검증 및 문서화

- **Files**: 빌드/테스트/문서 파일
- **Changes**: 워치 빌드 및 테스트 실행, solution/correction 기록
- **Verification**:
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEWatch -destination 'generic/platform=watchOS Simulator' build`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2' -only-testing:DUNEWatchTests -quiet`

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit `.ended` delegate 지연/누락 | watchdog timeout으로 `isFinalizingWorkout` 해제 |
| `end()` 중복 탭 | `guard !isSessionEnded`로 재진입 차단 |
| 이전 세션 delegate 콜백 늦게 도착 | session identity guard로 무시 |

## Testing Strategy

- Unit tests: 기존 `DUNEWatchTests` 스위트 회귀 실행
- Integration tests: watch target build + watch tests 실행
- Manual verification: 시뮬레이터에서 종료 다이얼로그 가시성/탭 후 요약 진입 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 즉시 종료 전환으로 finalize 이전 요약 노출 | 중간 | 중간 | 요약 화면 Done 버튼에서 `isFinalizingWorkout` 가드 유지 |
| watchdog timeout이 너무 짧아 UUID 캡처 실패 | 낮음 | 중간 | timeout 6초, 저장 시 `waitForWorkoutFinalization()` 추가 대기 |
| role 변경으로 destructive 강조 약화 | 낮음 | 낮음 | 기존 빨간 컨텍스트(종료 문구) 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: UI/상태전환/콜백 방어를 함께 적용했고, 워치 빌드/테스트를 실제 실행해 회귀를 검증했다.
