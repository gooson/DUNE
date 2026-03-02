---
topic: watch-logger-nonisolated-cleanup
date: 2026-03-02
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-02-16-swift6-healthkit-build-fixes.md
  - docs/solutions/general/2026-03-02-run-review-fix-batch.md
related_brainstorms: []
---

# Implementation Plan: Watch Logger Nonisolated Cleanup

## Context

Watch 타깃에서 Swift 6 컴파일러가 `Logger` 상수에 붙은 `nonisolated(unsafe)`가 불필요하다고 경고한다. 경고를 제거하여 strict concurrency 신호를 정리하고, 실제 actor 경계 의미를 명확히 유지해야 한다.

## Requirements

### Functional

- `WorkoutManager`와 `WatchConnectivityManager`의 logger 선언을 `nonisolated(unsafe)`에서 `nonisolated`로 변경한다.
- 기존 로그 출력 동작과 subsystem/category 값은 그대로 유지한다.

### Non-functional

- 변경 범위를 최소화하여 회귀 위험을 낮춘다.
- Swift 6 concurrency 관련 신규 경고를 만들지 않는다.

## Approach

`@MainActor` 클래스의 nonisolated delegate 경로에서 logger를 사용하므로 `nonisolated`는 유지하고 `unsafe`만 제거한다. 동작 변경이 없는 선언 정리이므로 로직/제어 흐름 수정은 하지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `nonisolated(unsafe)` 유지 | 코드 변경 없음 | 경고 지속, 불필요한 unsafe 신호 유지 | 미채택 |
| `nonisolated`까지 완전 제거 | 선언 단순화 | nonisolated delegate에서 logger 접근 시 actor isolation 컴파일 에러 | 미채택 |
| logger를 전역 유틸로 이동 | 재사용성 증가 가능 | 범위 과도 확장, 현재 문제와 무관 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNEWatch/Managers/WorkoutManager.swift | modify | logger 선언을 `nonisolated(unsafe)` → `nonisolated`로 변경 |
| DUNEWatch/WatchConnectivityManager.swift | modify | logger 선언을 `nonisolated(unsafe)` → `nonisolated`로 변경 |

## Implementation Steps

### Step 1: 불필요한 어노테이션 제거

- **Files**: `WorkoutManager.swift`, `WatchConnectivityManager.swift`
- **Changes**: `nonisolated(unsafe) private static let logger` → `nonisolated private static let logger`
- **Verification**: `rg`로 동일 패턴 제거 확인

### Step 2: 품질 확인

- **Files**: 위 2개 파일 + build log
- **Changes**: watch 빌드 시도 후 warning/error 로그 확인
- **Verification**: 관련 경고 문자열 재발 여부 확인

## Edge Cases

| Case | Handling |
|------|----------|
| logger 접근이 nonisolated delegate 경로에서 수행됨 | `Self.logger` 정적 접근은 유지되어 동작 영향 없음 |
| watchOS 빌드 환경 제약으로 전체 컴파일 검증 실패 | 로그에서 대상 경고 미재현 여부와 실패 원인 분리 보고 |

## Testing Strategy

- Unit tests: 선언부 변경만 있어 신규 테스트 미추가 (testing-required 면제 범위)
- Integration tests: `xcodebuild`로 `DUNEWatch` build 시도
- Manual verification: `git diff`, `rg` 스캔으로 변경 의도 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 실제 actor isolation 의미 변화 오해 | low | low | 선언부만 변경, 동작 경로 유지 |
| 환경 이슈로 완전 빌드 검증 불가 | medium | low | 실패 원인을 인프라 이슈로 분리 기록 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 컴파일러 진단 권고를 그대로 반영한 선언 정리이며 변경 범위가 두 줄로 제한되어 있다.
