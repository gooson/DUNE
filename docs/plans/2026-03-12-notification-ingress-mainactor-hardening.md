---
topic: Notification ingress main actor hardening
date: 2026-03-12
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-12-cloudkit-remote-change-mainactor-ingress.md
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
related_brainstorms: []
---

# Implementation Plan: Notification Ingress Main Actor Hardening

## Context

`NSPersistentStoreRemoteChange` 경로의 main actor 보정은 이미 들어갔지만, 저장소 안에는
`NotificationCenter.default.publisher(...).onReceive`에서 SwiftUI `@State` 또는 `@Observable @MainActor`
view model을 직접 갱신하는 ingress가 더 남아 있다.

`NotificationCenter` publisher는 delivery thread를 보장하지 않으므로, 이런 ingress가 background queue에서
실행되면 `Publishing changes from background threads is not allowed` 경고가 다시 발생할 수 있다.

## Requirements

### Functional

- NotificationCenter 기반 `onReceive` 진입점에서 SwiftUI state 변경과 `@MainActor` view model 갱신이 main actor에서 실행되어야 한다.
- 기존 refresh/reload behavior와 low-power mode 반응은 유지되어야 한다.
- remote change fix와 충돌 없이 동일한 main-actor ingress 패턴을 확장 적용해야 한다.

### Non-functional

- 수정 범위는 notification ingress hardening에 한정한다.
- 기존 데이터 fetch, throttle, animation 로직의 의미는 바꾸지 않는다.
- 변경 후 최소 build와 관련 unit tests로 회귀를 확인한다.

## Approach

`onReceive(NotificationCenter.default.publisher(...))`가 state를 만지는 곳을 선별해
closure 내부에서 즉시 `Task { @MainActor in ... }`로 main actor 경계를 고정한다.

이 접근은 새 Combine 의존이나 추가 abstraction 없이 기존 코드베이스의 actor-boundary 패턴과 맞고,
notification delivery thread와 무관하게 state mutation contract를 명확히 만든다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 각 publisher에 `receive(on: RunLoop.main)` 추가 | 선언적으로 main delivery 보장 | 기존 actor-boundary 패턴과 달라지고 파일별 `Combine` import가 늘어남 | 기각 |
| direct state mutation만 개별 hotfix | 변경량 최소 | 같은 문제 패턴이 다른 notification ingress에 남을 수 있음 | 기각 |
| notification ingress를 `Task { @MainActor in ... }`로 통일 | 기존 패턴 재사용, thread contract가 명확 | 일부 closure가 조금 더 장황해짐 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | modify | notification-driven app runtime refresh ingress를 명시적 main actor task로 고정 |
| `DUNE/App/ContentView.swift` | modify | notification route/mock refresh ingress를 main actor task로 고정 |
| `DUNEVision/App/VisionContentView.swift` | modify | mock refresh ingress를 main actor task로 고정 |
| `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift` | modify | mock notification 후 `refreshToken` state mutation을 main actor로 이동 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift` | modify | mock reload ingress를 main actor task로 고정 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | modify | mock reload + animation state mutation ingress를 main actor task로 고정 |
| `DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift` | modify | mock reload ingress를 main actor task로 고정 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | modify | low-power notification 후 `@State` mutation을 main actor로 이동 |

## Implementation Steps

### Step 1: Notification ingress inventory hardening

- **Files**: `DUNE/App/DUNEApp.swift`, `DUNE/App/ContentView.swift`, `DUNEVision/App/VisionContentView.swift`, `DUNEVision/Presentation/*`
- **Changes**:
  - background-delivered notification을 받는 `onReceive` closure를 `Task { @MainActor in ... }` 경유로 변경
  - mock data reload와 navigation routing처럼 state/view model을 건드리는 ingress를 모두 같은 패턴으로 정리
- **Verification**:
  - 수정된 `onReceive`에서 state mutation이 direct closure body에 남지 않았는지 확인

### Step 2: Shared visual state hardening

- **Files**: `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift`
- **Changes**:
  - power-state notification 이후 `isLowPowerModeEnabled` 변경을 main actor task 안으로 이동
- **Verification**:
  - low-power notification handler가 direct `@State` write를 하지 않는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| notification이 background queue에서 연속 발행 | 각 ingress가 즉시 main actor task로 hop 하므로 direct background publish를 차단 |
| mock-data notification 이후 async reload 중 추가 notification 도착 | 기존 reload throttling/guard는 각 view model이 유지하고 ingress만 안전하게 감싼다 |
| low-power mode notification이 앱 비활성 상태에서 도착 | state update만 main actor로 고정하고 기존 quality-mode 계산은 그대로 유지 |

## Testing Strategy

- Unit tests: `PersistentStoreRemoteChangeRefreshTests`
- Integration tests: `scripts/build-ios.sh`
- Manual verification:
  - CloudKit remote change, simulator mock data refresh, low-power mode change 시 console에 background publish warning이 없는지 확인
  - visionOS chart/dashboard/immersive refresh가 기존처럼 동작하는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| main actor hardening이 notification 처리 순서를 바꾸는 것처럼 보일 수 있음 | low | medium | 기존 async work는 그대로 두고 ingress boundary만 명시적으로 이동 |
| mock-data refresh path 일부가 이미 main actor였는데 중복 hop이 생김 | medium | low | 추가 hop은 cheap하며, warning 재발 방지 이점이 더 큼 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: unsafe pattern이 `NotificationCenter` ingress에 국한되어 있고, 기존 코드베이스도 이미 같은 문제를 `Task { @MainActor in ... }`로 해결한 전례가 있다.
