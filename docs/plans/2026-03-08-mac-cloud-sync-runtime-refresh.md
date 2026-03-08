---
topic: mac-cloud-sync-runtime-refresh
date: 2026-03-08
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-08-batch-fixes-summary.md
  - docs/solutions/general/2026-03-08-review-followup-state-and-migration-fixes.md
  - docs/solutions/architecture/2026-03-07-visionos-mirror-sync-gating-and-spatial-fallback.md
related_brainstorms:
  - docs/brainstorms/2026-03-03-macos-healthkit-cloud-sync-internalization.md
---

# Implementation Plan: Mac Cloud Sync Runtime Refresh

## Context

맥에서 HealthKit unavailable fallback이 `CloudMirroredSharedHealthDataService`를 사용하지만,
CloudKit 사용 여부는 `DUNEApp.init()`에서 한 번만 결정된다. iPhone에서 켠 cloud sync opt-in이
Mac 런타임에 늦게 도착하거나, Mac 앱이 opt-in 변경 전 상태로 시작되면 전체 세션 동안 local-only
container/service가 고정되어 mirrored data를 읽지 못할 수 있다.

## Requirements

### Functional

- Mac/HealthKit unavailable 환경에서 cloud sync preference 변경을 런타임에 감지한다.
- resolved cloud sync preference가 바뀌면 app runtime dependency를 재구성한다.
- 재구성 후 Today/Wellness/Activity 등 shared service 소비 화면이 새 dependency를 사용한다.

### Non-functional

- 기존 iOS/watch HealthKit runtime 동작을 회귀시키지 않는다.
- observer 중복 등록과 stale dependency 누수를 피한다.
- 테스트 가능한 pure policy/helper를 남긴다.

## Approach

`DUNEApp`의 container/service 초기화를 `AppRuntime` 값으로 추출하고, `NSUbiquitousKeyValueStore.didChangeExternallyNotification`
수신 시 `CloudSyncPreferenceStore.resolvedValue()`를 다시 평가한다. 값이 실제로 바뀐 경우에만 runtime을 재생성하고,
`ContentView` subtree identity를 교체해 cached `@State` view model도 새 shared service를 받게 만든다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 앱 시작 시 1회 결정 유지 + 재실행 안내 | 구현이 가장 단순 | 사용자가 Mac에서 opt-in 반영을 즉시 못 받음 | 기각 |
| Mac에서 CloudKit 항상 활성화 | mirrored data 수신 보장 | opt-in 계약 우회, local-only 의도 위반 | 기각 |
| runtime dependency 재구성 | opt-in 변경을 현재 세션에서 흡수 가능 | App init 의존성 추출이 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | refactor | rebuildable app runtime + KVS external-change handling 추가 |
| `DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift` | logic | cloud sync preference refresh helper 추가 |
| `DUNETests/HealthSnapshotMirrorContainerFactoryTests.swift` | test | runtime refresh policy / no-op 조건 검증 추가 |

## Implementation Steps

### Step 1: Rebuildable runtime 추출

- **Files**: `DUNE/App/DUNEApp.swift`
- **Changes**: model container, shared service, refresh coordinator, observer manager 생성을 `AppRuntime`로 추출
- **Verification**: 앱이 기존과 동일하게 build되고 body에서 runtime dependency를 참조

### Step 2: Cloud sync preference change handling 추가

- **Files**: `DUNE/App/DUNEApp.swift`, `DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift`
- **Changes**: KVS external change notification을 받아 resolved value 재평가 후 runtime 재생성
- **Verification**: resolved value가 동일하면 no-op, 변경되면 runtime revision이 갱신

### Step 3: 회귀 테스트 추가

- **Files**: `DUNETests/HealthSnapshotMirrorContainerFactoryTests.swift`
- **Changes**: refresh policy pure helper 테스트 추가
- **Verification**: `swift test --filter HealthSnapshotMirrorContainerFactoryTests` 또는 관련 scheme test 통과

## Edge Cases

| Case | Handling |
|------|----------|
| KVS notification이 반복 도착 | 실제 resolved 값이 바뀐 경우에만 runtime 재구성 |
| 기존 observer registration 중복 | runtime 교체 시 이전 observer를 중지하고 새 observer만 시작 |
| XCTest / UI test 경로 | 기존 test-only CloudKit OFF 정책 유지 |
| HealthKit available iPhone | cloud sync preference 변경이 있어도 HealthKit service wiring은 유지하되 runtime만 안전하게 재생성 |

## Testing Strategy

- Unit tests: cloud sync preference refresh policy helper
- Integration tests: affected Swift test suite / app target build
- Manual verification: iPhone에서 cloud sync enable 후 Mac 앱 foreground 상태에서 data refresh 반영 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| runtime 재구성 후 stale view model 유지 | medium | high | `ContentView` subtree identity 교체로 재초기화 보장 |
| observer duplicate registration | medium | medium | old observer stop 후 runtime 교체 |
| container rebuild가 예상치 못한 local state reset 유발 | low | medium | 변경 조건을 resolved value change로 제한 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 증상과 코드 구조는 강하게 맞지만, 실제 사용자 재현 로그 없이 startup/KVS 타이밍 이슈를 기준으로 수정한다. 대신 변경은 runtime refresh contract에 집중해 재현 범위를 넓게 막는다.
