---
topic: CloudKit remote change main actor fix
date: 2026-03-12
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-12-mac-cloudkit-remote-change-auto-refresh.md
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
related_brainstorms: []
---

# Implementation Plan: CloudKit Remote Change Main Actor Fix

## Context

Mac CloudKit remote change 알림 이후 `Publishing changes from background threads is not allowed`
경고가 반복된다. `ContentView`의 refresh stream 소비는 이미 `MainActor.run`으로 보호되어 있으므로,
남은 취약 지점은 `DUNEApp`의 `.NSPersistentStoreRemoteChange` 수신 시점이다.

현재 구현은 notification 수신 직후 일반 `Task`에서 `@State appRuntime`의 `refreshCoordinator`를 읽는다.
`NSPersistentStoreRemoteChange`는 background queue에서 전달될 수 있어, SwiftUI 상태 접근 경계가 흐려진다.

## Requirements

### Functional

- CloudKit remote change 수신 후 refresh 요청이 기존과 동일하게 `cloudKitRemoteChange` source로 전달되어야 한다.
- remote change 진입점에서 SwiftUI state(`appRuntime`) 접근이 main actor로 고정되어야 한다.
- 기존 throttle 및 refresh pipeline 동작은 유지되어야 한다.

### Non-functional

- 수정 범위는 app lifecycle ingress와 그 회귀 테스트로 제한한다.
- 기존 refresh stream/ContentView 구현은 건드리지 않는다.
- 회귀 테스트로 forwarding contract를 고정한다.

## Approach

remote change forwarding을 작은 `@MainActor` helper로 추출하고, `DUNEApp`의 notification handler는
`Task { @MainActor in ... }` 경계에서만 `appRuntime.refreshCoordinator`를 읽도록 바꾼다.

이 접근은 background-delivered notification을 그대로 받되, SwiftUI state 접근과 refresh dispatch를
명시적으로 main actor에 고정한다. helper를 별도 타입으로 두면 unit test에서 source forwarding을 검증할 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `DUNEApp` closure만 `Task { @MainActor in ... }`로 바꾸고 별도 helper는 두지 않음 | 구현이 가장 짧다 | forwarding contract를 테스트로 고정하기 어렵다 | 기각 |
| Combine `receive(on: RunLoop.main)` 추가 | publisher 단계에서 main delivery 보장 | `Combine` 의존 추가, state access contract가 코드상 덜 직접적 | 기각 |
| `@MainActor` helper + main-actor task boundary | state access 경계가 명확하고 테스트 seam 확보 가능 | 파일 1개와 테스트 1개가 추가된다 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | modify | remote change notification handler를 main actor helper 경유로 전환 |
| `DUNE/App/PersistentStoreRemoteChangeRefresh.swift` | add | CloudKit remote refresh forwarding helper 추가 |
| `DUNETests/PersistentStoreRemoteChangeRefreshTests.swift` | add | helper가 올바른 source로 coordinator를 호출하는지 검증 |

## Implementation Steps

### Step 1: Main actor ingress 고정

- **Files**: `DUNE/App/DUNEApp.swift`, `DUNE/App/PersistentStoreRemoteChangeRefresh.swift`
- **Changes**:
  - remote change forwarding helper를 `@MainActor`로 추가
  - `.NSPersistentStoreRemoteChange` handler에서 `Task { @MainActor in ... }`로 coordinator 접근 경계를 고정
- **Verification**:
  - 코드상 `appRuntime.refreshCoordinator` 접근이 main-actor task 내부에만 존재하는지 확인

### Step 2: Regression coverage 추가

- **Files**: `DUNETests/PersistentStoreRemoteChangeRefreshTests.swift`
- **Changes**:
  - mock coordinator로 helper가 `cloudKitRemoteChange` source를 전달하는지 검증
  - helper가 `requestRefresh`를 정확히 1회 호출하는지 검증
- **Verification**:
  - 대상 test 통과

## Edge Cases

| Case | Handling |
|------|----------|
| remote change notification이 background queue에서 연속 도착 | main actor ingress만 고정하고, throttle은 기존 coordinator가 계속 처리 |
| cloud sync runtime rebuild 직후 새 coordinator로 교체된 상태 | handler가 실행 시점의 `appRuntime.refreshCoordinator`를 main actor에서 읽어 최신 coordinator를 사용 |
| refresh가 throttled 되는 경우 | helper는 source forwarding만 담당하고 반환값은 무시, 기존 로그/동작 유지 |

## Testing Strategy

- Unit tests: `PersistentStoreRemoteChangeRefreshTests`, `AppRefreshCoordinatorTests`
- Integration tests: `scripts/build-ios.sh`
- Manual verification:
  - Mac CloudKit remote change 후 console에 background publish 경고가 사라지는지 확인
  - throttled 로그만 남고 UI refresh는 기존과 동일하게 유지되는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| helper 추출이 불필요한 구조 추가로 보일 수 있음 | low | low | helper를 forwarding 한정 타입으로 유지하고 DUNEApp 외 사용 금지 |
| unit test가 thread warning 자체를 직접 재현하지 못함 | medium | medium | main-actor annotation + call-site boundary를 코드 구조로 강제하고 manual verification 병행 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 저장소에서 이미 downstream refresh state는 main actor로 보호되고 있고, 남은 ingress가 `DUNEApp` remote change handler 하나로 좁혀진 상태다.
