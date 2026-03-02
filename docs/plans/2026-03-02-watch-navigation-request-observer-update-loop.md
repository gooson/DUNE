---
topic: Watch NavigationRequestObserver multi-update warning fix
date: 2026-03-02
status: implemented
confidence: high
related_solutions:
  - architecture/2026-02-18-watch-navigation-state-management.md
  - general/2026-03-02-watchos-nested-navigationstack-crash.md
related_brainstorms: []
---

# Implementation Plan: Watch NavigationRequestObserver Multi-Update Warning Fix

## Context

watchOS `ContentView`에서 workout 상태 전환 시 `navigationPath`를 서로 다른 `onChange` 두 곳에서 같은 프레임에 갱신하면서, 런타임 경고(`NavigationRequestObserver tried to update multiple times per frame`)가 발생했다.

## Requirements

### Functional

- workout 시작/종료 전환 시 push stack은 안전하게 pop 되어야 한다.
- 세션 종료 시점(`sessionEndDate`) 캡처는 유지되어야 한다.
- 네비게이션 경로 갱신은 한 프레임에 중복 실행되지 않아야 한다.

### Non-functional

- 기존 watch navigation 패턴(`NavigationStack(path:)`)을 유지한다.
- 변경 범위를 최소화하고 회귀 가능성을 낮춘다.
- watchOS 타깃 빌드가 통과해야 한다.

## Approach

`isActive`/`isSessionEnded`를 하나의 관찰 상태로 통합해 단일 `onChange`에서만 `navigationPath`를 제어한다. 또한 path가 이미 비어 있으면 재할당을 생략해 불필요한 네비게이션 요청을 막는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 `onChange` 2개 유지 + 디바운스 | 코드 변경이 작아 보임 | 상태 전환 타이밍 의존, 원인(중복 write) 미해결 | Rejected |
| 단일 `onChange` + 관찰 상태 래핑(채택) | navigation write 단일화, 의도 명확 | 작은 보일러플레이트 추가 | Accepted |
| `Task { @MainActor }` 지연 처리 | 프레임 충돌 가능성 완화 | 비결정적 타이밍, 상태 추론 어려움 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNEWatch/ContentView.swift | Modify | 네비게이션 상태 관찰 통합 및 중복 path reset 방지 |

## Implementation Steps

### Step 1: Navigation state observer 통합

- **Files**: `DUNEWatch/ContentView.swift`
- **Changes**: `NavigationObserverState`(Equatable) 추가, 단일 `onChange`에서 시작/종료 전환만 처리
- **Verification**: 동일 이벤트에서 `navigationPath` write가 1회로 제한되는지 코드 레벨 확인

### Step 2: 중복 path reset 방지

- **Files**: `DUNEWatch/ContentView.swift`
- **Changes**: `guard navigationPath.count > 0` 조건 추가
- **Verification**: path가 이미 빈 상태에서는 reset을 스킵하는지 확인

### Step 3: 상태 정리 보완

- **Files**: `DUNEWatch/ContentView.swift`
- **Changes**: `isSessionEnded == false` 시 `sessionEndDate = nil`
- **Verification**: 다음 세션에서 stale end date가 남지 않는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 시작과 종료 상태가 짧은 구간에 연속 변경 | 단일 `onChange`에서 전환 조건 계산 후 1회만 path reset |
| path가 이미 비어 있음 | reset 생략하여 불필요한 NavigationRequest 차단 |
| 세션 리셋 후 요약 화면 조건 잔존 | `sessionEndDate` 초기화로 stale 상태 제거 |

## Testing Strategy

- Unit tests: 이번 변경은 SwiftUI view modifier wiring 중심이라 신규 유닛 테스트는 생략
- Integration tests: watchOS target 빌드 성공 확인
- Manual verification:
  - workout preview 진입 후 시작 -> session 화면 전환 시 경고 미발생
  - workout 종료 -> summary 전환 시 경고 미발생
  - summary 종료 후 idle 복귀 -> 다음 workout 시작 시 정상 전환

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 상태 래핑으로 `onChange` 트리거 누락 | low | medium | 시작/종료 두 전환을 명시적으로 계산 |
| path reset 조건 과도 제한 | low | medium | `startedWorkout || endedWorkout` 조건 유지 |
| summary 표시 조건 회귀 | low | high | `sessionEndDate` 설정/초기화 분리 검증 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 근본 원인(동일 프레임 다중 navigation write)을 직접 제거하는 구조 변경이며, watch target 빌드로 컴파일 안정성도 확인 가능하다.
