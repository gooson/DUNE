---
topic: healthmetric-sleep-format-test-fix
date: 2026-03-02
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-02-22-number-label-thousand-separator-standardization.md
related_brainstorms: []
---

# Implementation Plan: HealthMetric Sleep Format Test Fix

## Context

GitHub Actions 단위 테스트에서 `HealthMetricTests.formattedValue`가 실패했다. 원인은 수면 시간 포맷의 기대값이 `"7h 30m"`로 남아 있지만 실제 구현은 `hoursMinutesFormatted`를 통해 `"7h 30min"`을 반환하기 때문이다.

## Requirements

### Functional

- `HealthMetric`의 수면 포맷 테스트 기대값을 현재 구현 규칙(`min`)과 일치시킨다.
- CI 실패 테스트 1건을 해소한다.

### Non-functional

- 코드 변경 범위를 테스트 파일 1곳으로 제한한다.
- 기존 포맷 규칙 및 다른 테스트 동작에 영향이 없어야 한다.

## Approach

구현 코드는 이미 프로젝트 전반에서 `min` 표기를 사용하고 있으므로, 모델/확장을 수정하지 않고 테스트 기대값만 수정한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 테스트 기대값을 `"7h 30min"`으로 변경 | 변경 최소화, 기존 UI/포맷 규칙 유지 | 없음(의도된 규칙과 일치) | 채택 |
| 구현을 `"7h 30m"`로 롤백 | 테스트만 통과 가능 | 프로젝트 전반 `min` 규칙과 충돌, 회귀 위험 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNETests/HealthMetricTests.swift | modify | sleep formattedValue 기대 문자열 수정 |

## Implementation Steps

### Step 1: 실패 테스트 정합성 수정

- **Files**: `DUNETests/HealthMetricTests.swift`
- **Changes**: `sleep.formattedValue` 기대값을 `"7h 30m"`에서 `"7h 30min"`으로 변경
- **Verification**: 해당 테스트 assertion이 구현 반환값과 일치하는지 확인

### Step 2: 품질 검증

- **Files**: 없음(실행 검증)
- **Changes**: `scripts/test-unit.sh` 재실행으로 회귀 확인
- **Verification**: 테스트 실패가 없으면 완료. 시뮬레이터 인프라 오류 시 원인 로그를 함께 기록

## Edge Cases

| Case | Handling |
|------|----------|
| CI 외 로컬 시뮬레이터 런타임 장애 | 코드 회귀와 환경 장애를 분리하여 보고 |
| 다른 포맷 테스트 회귀 | 동일 파일 내 인접 assertion 유지 여부 점검 |

## Testing Strategy

- Unit tests: `scripts/test-unit.sh` 실행
- Integration tests: N/A (테스트 기대값 단일 수정)
- Manual verification: `HealthMetric+View` 및 `Duration+Formatting`의 `min` 규칙과 기대값 일치 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 실제 포맷 의도와 테스트가 다시 불일치 | low | low | 공통 포맷 함수(`hoursMinutesFormatted`)를 기준으로 테스트 유지 |
| 로컬 검증 실패가 코드 실패로 오인 | medium | low | CoreSimulator 오류 로그를 별도 명시 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 실패 원인과 수정 지점이 1:1로 대응하며 변경 범위가 단일 assertion이다.
