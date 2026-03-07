---
topic: launch-argument-mainactor-isolation-fix
date: 2026-03-08
status: approved
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/architecture/watch-settings-sync-pattern.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: Launch Argument MainActor Isolation Fix

## Context

`DUNE/App/DUNEApp.swift` 에서 UI test launch argument를 파싱하는 `static` helper가 Swift 6 actor isolation 규칙과 충돌한다.
현재 `UITestLaunchConfiguration.current(...)` 같은 synchronous nonisolated 문맥에서 `launchArgumentValue(for:)` 를 호출할 때, 컴파일러가 이를 main actor-isolated static method로 해석해 빌드가 실패한다.

## Requirements

### Functional

- `DUNEApp` 의 UI test launch argument parsing이 다시 컴파일되어야 한다.
- `--ui-scenario`, `--ui-test-theme`, `--ui-test-style` 해석 동작은 기존과 동일해야 한다.

### Non-functional

- 변경 범위는 최소화한다.
- 기존 UI test infrastructure pattern과 충돌하지 않는다.
- launch-time synchronous parsing에서 불필요한 actor hop을 만들지 않는다.

## Approach

`ProcessInfo.processInfo.arguments` 만 읽는 순수 static helper를 `nonisolated` 로 명시한다.
필요 시 해당 helper를 사용하는 파생 static computed property도 같은 isolation 관점에서 점검하되, 동작 변경 없이 compile fix에 필요한 최소 범위만 수정한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `launchArgumentValue(for:)` 를 `nonisolated` 로 명시 | 최소 변경, 기존 call site 유지, 순수 함수 의도 명확 | helper가 truly pure 여야 함 | Selected |
| call site를 `@MainActor` 로 이동 | actor 규칙상 안전 | launch config 계산 범위가 커지고 불필요한 main actor 전파 발생 | Rejected |
| helper를 전역 함수/별도 타입으로 분리 | isolation 분리 명확 | 파일 구조 변경이 과함, 요청 범위 초과 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | code | launch argument helper isolation 수정 및 compile-safe parsing 유지 |

## Implementation Steps

### Step 1: Isolate pure launch-argument helper correctly

- **Files**: `DUNE/App/DUNEApp.swift`
- **Changes**: `launchArgumentValue(for:)` 의 actor isolation을 명시적으로 조정하고, 관련 static launch config accessors가 동일 helper를 안전하게 사용하도록 정리
- **Verification**: 해당 호출부의 actor isolation compile error가 사라져야 함

### Step 2: Verify build and regression surface

- **Files**: `DUNE/App/DUNEApp.swift`
- **Changes**: 없음 (검증 단계)
- **Verification**: iOS app build가 통과하고, launch argument parsing 관련 추가 경고/에러가 없어야 함

## Edge Cases

| Case | Handling |
|------|----------|
| launch argument key가 없거나 값이 뒤따르지 않음 | 기존처럼 `nil` 반환 유지 |
| UI test가 아닌 실행 경로 | 기존 guard (`isRunningUITests`) 유지 |
| helper에 actor-isolated 상태 접근이 섞이는 미래 변경 | solution doc과 prevention에 pure helper 원칙 기록 |

## Testing Strategy

- Unit tests: 없음. 이번 변경은 순수 compile-fix이며 기존 parsing 로직 분기 자체는 바뀌지 않는다.
- Integration tests: `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE`
- Manual verification: build 로그에서 `launchArgumentValue(for:)` 관련 actor isolation 에러 제거 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `nonisolated` helper가 이후 actor-isolated 상태를 참조하게 되는 회귀 | low | medium | helper를 `ProcessInfo` 기반 pure parser로 유지하고 solution doc에 예방 규칙 기록 |
| call site 중 일부가 여전히 isolated static property로 판정될 가능성 | low | medium | build로 전체 파일 재검증 후 필요 시 동일 범위의 pure static accessor 추가 정리 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 저장소 내 기존 solution이 동일한 Swift 6 actor-isolation 패턴을 이미 문서화하고 있고, 현재 문제도 동일하게 순수 static helper 경계만 바로잡으면 해결될 가능성이 높다.
