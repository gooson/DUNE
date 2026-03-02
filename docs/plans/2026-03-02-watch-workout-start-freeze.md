---
topic: Watch Workout Start Freeze
date: 2026-03-02
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/healthkit/2026-03-02-watch-cardio-distance-tracking.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
  - docs/solutions/general/2026-03-02-run-review-fix-batch.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-watch-workout-start-freeze.md
---

# Implementation Plan: Watch Workout Start Freeze

## Context

워치 시뮬레이터에서 운동 시작 버튼(근력/카디오 공통) 탭 후 스피너가 계속 노출되고 세션 시작 화면으로 전환되지 않는 문제가 발생한다. 카디오 전용 이슈가 아니라 공통 시작 경로 이슈이며, `HealthKit 권한 요청` 또는 `beginCollection` 대기 구간에서 무한 대기 가능성이 크다.

## Requirements

### Functional

- 운동 시작 시 무한 로딩이 발생하지 않아야 한다.
- 시작 실패 시 사용자에게 재시도 가능한 원인 메시지를 제공해야 한다.
- 근력/카디오 시작 경로 모두 동일한 방어 로직을 적용해야 한다.

### Non-functional

- 기존 Watch 시작 UX 흐름(버튼/로딩/알럿)은 유지한다.
- 실패 시 세션 상태가 꼬이지 않도록 일관성을 보장한다.
- 시뮬레이터 환경에서도 진단 가능한 로그/에러 분기가 있어야 한다.

## Approach

공통 시작 경로인 `WorkoutManager.requestAuthorization` 및 `startHKSession(beginCollection)`에 timeout guard를 추가하고, 실패 원인을 `WorkoutStartupError`로 표준화해 View에서 분기 표시한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 무한 대기 유지 + generic 에러 | 구현 최소 | 사용자 체감 무반응 지속, 원인 불명 | 기각 |
| View 레벨 타이머만 추가 | UI는 빠르게 복구 | Manager 상태 불일치 가능, 중복 로직 | 기각 |
| Manager 공통 경로 timeout + typed error | 근력/카디오 동시 해결, 상태/원인 관리 용이 | 구현 복잡도 소폭 증가 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Managers/WorkoutManager.swift` | modify | authorization/beginCollection timeout + startup error 분기 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | modify | 시작 실패 에러 메시지 세분화 |
| `docs/brainstorms/2026-03-02-watch-workout-start-freeze.md` | add | 요구사항/가설/범위 정리 |
| `docs/plans/2026-03-02-watch-workout-start-freeze.md` | add | 구현 계획 기록 |

## Implementation Steps

### Step 1: 공통 시작 경로 timeout 도입

- **Files**: `WorkoutManager.swift`
- **Changes**: `requestAuthorization`, `startHKSession` 대기 구간에 timeout 유틸 적용
- **Verification**: 10초 내 성공/실패로 반드시 종결되는지 확인

### Step 2: 시작 실패 에러 타입 표준화

- **Files**: `WorkoutManager.swift`
- **Changes**: `WorkoutStartupError` 추가 (`authorizationTimedOut`, `authorizationNotGranted`, `beginCollectionTimedOut`)
- **Verification**: 각 경로에서 예상 타입으로 throw 되는지 확인

### Step 3: UI 에러 노출 개선

- **Files**: `WorkoutPreviewView.swift`
- **Changes**: generic 문구 대신 startup error description 우선 노출
- **Verification**: 실패 시 원인 기반 메시지 표시 + 기존 alert 흐름 유지

### Step 4: 품질 검증

- **Files**: build/test command
- **Changes**: watch target build 실행 및 실패 원인 분리(코드/환경)
- **Verification**: 코드 오류 없음 또는 환경 이슈로 분리 보고

## Edge Cases

| Case | Handling |
|------|----------|
| 권한 팝업/콜백이 오지 않음 | authorization timeout으로 종료 |
| 권한 거부 상태 | authorizationNotGranted로 종료 |
| beginCollection이 반환되지 않음 | beginCollectionTimedOut으로 종료 |
| 근력/카디오 모두 무반응 | 공통 경로에 동일 guard 적용으로 동시 커버 |

## Testing Strategy

- Unit tests: HealthKit 실객체 의존으로 단위테스트 제한, 오류 타입 분기/메시지는 코드 리뷰로 검증
- Integration tests: watch 시뮬레이터에서 근력/카디오 시작 흐름 수동 확인
- Manual verification:
  - Strength Start 탭 후 10초 내 세션 진입 또는 에러 알럿
  - Cardio Outdoor/Indoor 탭 후 동일 검증

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| timeout 시 세션 상태 잔존 | medium | high | 시작 실패 경로에서 상태 정리 보강 |
| 시뮬레이터 자체 불안정으로 오탐 | high | medium | 빌드/런타임 에러를 환경 이슈로 분리 기록 |
| 실기기와 시뮬레이터 동작 차이 | medium | medium | 실기기 재검증 항목으로 분리 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 무한 대기 방지는 즉시 완화 가능하나, 시뮬레이터/실기기 권한 콜백 편차로 추가 검증이 필요하다.
