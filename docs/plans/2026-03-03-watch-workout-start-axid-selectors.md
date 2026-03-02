---
topic: Watch Workout Start AXID Selectors
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-02-nightly-full-ui-test-hardening.md
  - docs/solutions/general/2026-03-03-watch-simulator-cloudkit-noaccount-fallback.md
related_brainstorms: []
---

# Implementation Plan: Watch Workout Start AXID Selectors

## Context

watch 시작 스모크 테스트가 사용자 노출 문자열("Start", "Complete Set") 기반 selector를 사용하고 있어 locale 변경 시 테스트가 깨질 위험이 있다.

## Requirements

### Functional

- 운동 시작 스모크 테스트가 locale과 무관하게 안정적으로 동작해야 한다.
- 시작/세션 진입 핵심 버튼에 고정 accessibility identifier를 제공해야 한다.

### Non-functional

- 기존 사용자 UI/문구는 변경하지 않는다.
- 변경은 watch UI + watch UI 테스트 범위로 한정한다.

## Approach

문자열 selector를 AXID selector로 전환한다.
- View: `accessibilityIdentifier` 추가
- UITest: 문자열 탐색 제거, AXID 조회로 대체

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 문자열 selector 유지 | 코드 변경 최소 | locale/copy 변경에 취약 | 기각 |
| AXID selector 전환 | locale 독립적, 회귀 안정성 높음 | View에 식별자 추가 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Views/WorkoutPreviewView.swift` | modify | 시작 버튼/카디오 버튼 AXID 추가 |
| `DUNEWatch/Views/MetricsView.swift` | modify | 세션 진입 확인용 Complete Set 버튼 AXID 추가 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | modify | exercise row에 stable AXID 추가 |
| `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift` | modify | 문자열 selector 제거, AXID selector 사용 |

## Implementation Steps

### Step 1: Watch UI에 AXID 부여

- **Files**: `WorkoutPreviewView.swift`, `MetricsView.swift`, `QuickStartAllExercisesView.swift`
- **Changes**: 시작 플로우 핵심 요소에 AXID 부여
- **Verification**: 접근성 트리에서 식별 가능 여부 확인

### Step 2: Start smoke 테스트 selector 전환

- **Files**: `WatchWorkoutStartSmokeTests.swift`
- **Changes**: 문자열 조회를 AXID 조회로 교체
- **Verification**: watch simulator에서 단일 테스트 통과

### Step 3: 회귀 검증

- **Files**: build/test commands
- **Changes**: watch build + watch UI test 실행
- **Verification**: 빌드/테스트 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 언어가 영어가 아닐 때 | AXID 기반으로 동일 동작 |
| 운동명 copy 변경 | exercise row AXID(id 기반)로 영향 차단 |

## Testing Strategy

- UI tests: watch start smoke 단일 케이스 재실행
- Manual: 필요 시 watch simulator에서 All Exercises → Start 흐름 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| AXID naming drift | low | medium | 테스트와 동일 prefix 규칙 사용 |
| exercise ID format 변경 | low | low | fixture ID 고정(`ui-test-squat`) |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 UI-test hardening 패턴(AXID 전환)과 동일하며 변경 범위가 좁다.
