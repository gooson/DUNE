---
topic: vision-dashboard-e2e-surface-inventory
date: 2026-03-09
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: VisionDashboard E2E Surface Inventory

## Context

`todos/085-done-p3-e2e-dunevision-dashboard-view.md`의 선행 상태는 entry route, selector inventory, assertion scope가 비어 있었다. 현재 `VisionContentView`는 section-level lane identifier만 고정되어 있고, `VisionDashboardView` 내부의 condition/quick action/metric/mock-data surface는 회귀용 anchor가 없었다. 이번 배치는 dashboard 자체의 surface inventory를 코드와 TODO 문서에 함께 고정해 visionOS E2E Phase 0 backlog를 한 단계 더 닫는다.

## Requirements

### Functional

- `VisionDashboardView`의 root surface와 핵심 section anchor를 stable accessibility identifier로 고정한다.
- quick action card와 health metric card에 재사용 가능한 selector를 부여한다.
- `todos/085-done-p3-e2e-dunevision-dashboard-view.md`에 entry route, selector inventory, assertion scope, deferred lane 조건을 실제 코드 기준으로 기록한다.

### Non-functional

- 기존 window/immersive/open action wiring은 바꾸지 않는다.
- identifier는 공용 helper를 통해 관리해 drift를 줄인다.
- visionOS 전용 XCUITest harness 구축은 이번 범위에서 제외한다.

## Approach

`VisionSurfaceAccessibility`에 dashboard 전용 identifier helper를 추가하고, `VisionDashboardView`의 주요 section 및 카드에 연결한다. 테스트는 helper가 제공하는 identifier mapping의 안정성과 유일성을 검증하고, TODO 문서는 같은 inventory를 source of truth로 기록한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| TODO 문서만 채운다 | 구현량이 가장 적음 | 코드에 selector가 고정되지 않아 회귀 가치가 낮음 | 기각 |
| `VisionDashboardView` 안에 문자열을 직접 하드코딩한다 | 빠르게 적용 가능 | helper/test/doc 간 drift 위험이 큼 | 기각 |
| 공용 helper + view wiring + 테스트 + TODO 업데이트 | inventory를 한 곳에서 관리하고 회귀 가능 | 파일 수가 조금 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | modify | dashboard root/section/card selector helper 추가 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | modify | dashboard surface에 accessibility identifier 연결 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | modify | dashboard selector mapping/유일성 회귀 테스트 추가 |
| `todos/085-done-p3-e2e-dunevision-dashboard-view.md` | modify | dashboard surface inventory와 deferred lane 조건 기록 |

## Implementation Steps

### Step 1: Dashboard selector inventory 정의

- **Files**: `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift`
- **Changes**: dashboard root, section anchor, quick action card, metric card, mock data section identifier를 helper 상수/함수로 추가
- **Verification**: 테스트에서 identifier 값과 uniqueness를 검증

### Step 2: VisionDashboardView에 identifier 연결

- **Files**: `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift`
- **Changes**: root scroll surface, condition section, quick action section, quick action buttons, metric section, metric cards, mock data section에 accessibility identifier 부여
- **Verification**: build 성공, `rg "vision-dashboard-" DUNEVision/Presentation/Dashboard/VisionDashboardView.swift`로 주입 위치 확인

### Step 3: 테스트와 TODO 문서 동기화

- **Files**: `DUNETests/VisionSurfaceAccessibilityTests.swift`, `todos/085-done-p3-e2e-dunevision-dashboard-view.md`
- **Changes**: selector inventory 회귀 테스트 추가, TODO를 done 상태로 갱신하고 entry/state/deferred lane을 코드 기준으로 기록
- **Verification**: 관련 테스트 통과, TODO 문서 체크리스트 완료

## Edge Cases

| Case | Handling |
|------|----------|
| Simulator mock section은 환경에 따라 노출 여부가 다름 | section ID는 고정하되 assertion scope에서 optional lane으로 문서화 |
| quick action은 실제로 새 window/immersive를 연다 | 이번 배치에서는 버튼 존재와 selector 안정성만 다루고 open action 검증은 deferred로 남긴다 |
| metric value는 실데이터 유무에 따라 바뀜 | value text 대신 카드 container identifier를 anchor로 사용한다 |

## Testing Strategy

- Unit tests: `VisionSurfaceAccessibilityTests`에 dashboard selector mapping/uniqueness 추가
- Integration tests: 없음. visionOS XCUITest harness는 deferred 유지
- Manual verification: `scripts/build-ios.sh`, `scripts/test-unit.sh --ios-only`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| dashboard 레이아웃 리팩터링 후 selector가 stale 됨 | medium | medium | helper를 source of truth로 두고 테스트로 고정 |
| quick action/window scene TODO와 inventory 범위가 혼동됨 | medium | low | TODO 문서에 deferred lane을 명시적으로 적는다 |
| simulator mock section 조건부 노출로 assertion이 흔들림 | medium | medium | optional lane으로 문서화하고 section root ID를 별도로 둔다 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 vision surface inventory 패턴이 이미 있고, 이번 변경은 dashboard 한 화면의 selector 고정과 문서 동기화에 한정되어 범위가 작고 검증 가능하다.
