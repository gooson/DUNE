---
topic: vision-deferred-surface-e2e-batch
date: 2026-03-09
status: approved
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
  - docs/solutions/testing/2026-03-09-vision-content-surface-e2e-inventory.md
  - docs/solutions/testing/2026-03-09-vision-dashboard-surface-inventory.md
  - docs/solutions/testing/2026-03-09-vision-train-surface-inventory.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: Vision Deferred Surface E2E Batch

## Context

Vision Pro backlog에서 즉시 닫을 수 있는 deferred surface TODO는 `087 VisionDashboardWindowScene`, `089 VisionVolumetricExperienceView`, `090 VisionImmersiveExperienceView` 세 개다. 이미 `084/085/086/088`은 `VisionSurfaceAccessibility` helper, 실제 view wiring, stability test, TODO 동기화 패턴으로 정리되어 있다. 이번 배치는 남은 DUNEVision surface 세 개도 같은 패턴으로 한 번에 처리해, "Vision Pro 다음 작업"을 단일 TODO가 아니라 일관된 묶음으로 닫는 데 목적이 있다.

## Requirements

### Functional

- `VisionDashboardWindowScene`의 root/state/hero/section inventory를 stable selector로 고정한다.
- `VisionVolumetricExperienceView`의 root/state/ornament/scene selector를 stable selector로 고정한다.
- `VisionImmersiveExperienceView`의 root/header/control/state/action selector를 stable selector로 고정한다.
- `VisionSurfaceAccessibilityTests`에 새 selector mapping/uniqueness 회귀를 추가한다.
- `todos/087`, `todos/089`, `todos/090`을 실제 코드 기준 inventory로 채우고 `done` 상태로 갱신한다.
- `todos/021-ready-p2-e2e-phase0-page-backlog-index.md`의 링크를 새 `done` 파일명으로 동기화한다.

### Non-functional

- visionOS 전용 XCUITest harness 구축은 이번 범위에 포함하지 않는다.
- 실제 window open, volumetric open, immersive open/close 자동화는 deferred lane으로 유지한다.
- selector 문자열은 기존과 동일하게 `VisionSurfaceAccessibility`에 모아 drift를 줄인다.
- 기존 scene/view layout과 기능 동작은 바꾸지 않고 assertion anchor만 보강한다.

## Approach

기존 `084/085/086/088` 배치와 동일하게 공용 helper를 확장하고, surface view에 root/section/state/action anchor를 연결한 뒤, shared unit test와 TODO 문서를 같은 vocabulary로 갱신한다. `087`, `089`, `090`은 모두 DUNEVision deferred surface이며 UI harness 미구축 상태라는 공통점이 있으므로, 문서와 selector policy를 한 배치로 묶는 편이 가장 효율적이다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| TODO 문서만 채운다 | 구현량이 가장 적음 | 코드에 selector가 고정되지 않아 회귀 가치가 낮음 | 기각 |
| surface별로 개별 배치를 나눈다 | diff가 더 작아짐 | helper/test/TODO를 세 번 반복하게 되어 비효율적 | 기각 |
| helper + 3개 surface wiring + shared test + TODO sync를 한 배치로 묶는다 | 반복 패턴을 한 번에 적용하고 backlog를 빠르게 정리 가능 | 관련 파일 수가 조금 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | modify | window scene / volumetric / immersive selector inventory 추가 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift` | modify | window scene root/state/section/action identifier 연결 |
| `DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift` | modify | volumetric root/state/ornament/scene identifier 연결 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | modify | immersive root/header/control/state/action identifier 연결 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | modify | 새 selector stability/uniqueness 테스트 추가 |
| `todos/087-ready-p3-e2e-dunevision-dashboard-window-scene.md` | move+modify | done 상태로 갱신하고 inventory 문서화 |
| `todos/089-ready-p3-e2e-dunevision-volumetric-experience-view.md` | move+modify | done 상태로 갱신하고 inventory 문서화 |
| `todos/090-ready-p3-e2e-dunevision-immersive-experience-view.md` | move+modify | done 상태로 갱신하고 inventory 문서화 |
| `todos/021-ready-p2-e2e-phase0-page-backlog-index.md` | modify | backlog index 링크를 done 파일명으로 동기화 |

## Implementation Steps

### Step 1: Shared selector inventory 확장

- **Files**: `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift`
- **Changes**: dashboard window scene, volumetric experience, immersive experience의 root/state/section/action selector 상수와 helper를 추가한다.
- **Verification**: `VisionSurfaceAccessibilityTests`에서 identifier 값과 uniqueness를 고정할 수 있어야 한다.

### Step 2: 각 DUNEVision surface에 AXID wiring

- **Files**: `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift`, `DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift`, `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift`
- **Changes**:
  - window scene: root, loading/unavailable state, hero card, detail section, activity recent sessions, refresh action
  - volumetric: root, loading/message state, scene stage, picker ornament, trailing metric ornament, muscle strip
  - immersive: root, header, refresh/close actions, control panel, loading/ready/error state, recovery action
- **Verification**: `rg "vision-(window|volumetric|immersive)-" ...` 결과로 wiring 위치가 확인돼야 한다.

### Step 3: 테스트와 TODO/backlog 동기화

- **Files**: `DUNETests/VisionSurfaceAccessibilityTests.swift`, `todos/087-*.md`, `todos/089-*.md`, `todos/090-*.md`, `todos/021-ready-p2-e2e-phase0-page-backlog-index.md`
- **Changes**: selector stability/uniqueness 테스트를 추가하고, TODO 세 개를 `done`으로 rename/update하며 entry route, selector inventory, assertion scope, deferred lane을 코드 기준으로 기록한다. backlog index 링크도 함께 수정한다.
- **Verification**: 관련 unit test 통과, TODO 체크리스트 완료, backlog index에 stale ready 링크가 남지 않아야 한다.

## Edge Cases

| Case | Handling |
|------|----------|
| `VisionDashboardWindowScene`는 `kind`별로 내용이 달라짐 | 공통 root/state/hero/refresh anchor를 두고 kind별 detail/recent-session lane은 helper 함수로 분기한다 |
| volumetric experience는 ornament와 main scene이 분리돼 있음 | main root와 ornament anchor를 별도 selector로 분리해 later harness가 표면별 assert를 할 수 있게 한다 |
| immersive experience는 `summary` 유무와 selected mode에 따라 UI가 바뀜 | header/control root는 항상 고정하고, loading/error/ready/recovery action은 state별 selector로 분리한다 |
| 실제 openWindow / openImmersiveSpace 자동화는 로컬에서 아직 어렵다 | TODO 문서에 deferred lane으로 명시하고 이번 범위는 selector inventory 고정까지만 포함한다 |

## Testing Strategy

- Unit tests: `VisionSurfaceAccessibilityTests`에 window scene / volumetric / immersive selector mapping 및 uniqueness 추가
- Integration tests: 없음. visionOS XCUITest harness와 실제 spatial open/close 자동화는 deferred 유지
- Manual verification: `scripts/build-ios.sh`, `scripts/test-unit.sh --ios-only`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| selector naming이 surface마다 제각각 늘어날 수 있음 | medium | medium | helper에 접두사별로 모으고 tests에서 유일성 검증 |
| kind/state 조건부 UI 때문에 TODO inventory가 stale 될 수 있음 | medium | medium | state별 container와 kind helper를 분리해 문서/코드 vocabulary를 맞춘다 |
| deferred lane과 이번 범위가 혼동될 수 있음 | low | medium | TODO 문서에 "존재 assert"와 "실제 open/close automation"을 명확히 분리 기록 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 동일 패턴이 `084/085/086/088`에서 이미 검증되었고, 이번 변경은 남은 DUNEVision surface 세 개에 selector inventory를 확장하는 반복 작업이다. 기능 로직을 바꾸지 않고 assertion anchor만 추가하므로 리스크가 낮고 검증 경로도 명확하다.
