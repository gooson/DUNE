---
topic: vision-train-e2e-surface-inventory
date: 2026-03-09
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-09-vision-content-surface-e2e-inventory.md
  - docs/solutions/testing/2026-03-09-vision-dashboard-surface-inventory.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: VisionTrain E2E Surface Inventory

## Context

Vision Pro backlog에서 broad epic인 `todos/022-in-progress-p2-vision-ux-polish.md`는 spatial placement 실검증만 남아 있고, `todos/023-in-progress-p2-vision-phase4-remaining.md`는 실기기 의존 advanced scope가 중심이다. 현재 로컬에서 바로 닫을 수 있는 다음 Vision Pro TODO는 `todos/086-ready-p3-e2e-dunevision-train-view.md`이며, `VisionTrainView`는 아직 root/state/card selector inventory가 거의 없어 TODO를 코드 기준으로 닫을 수 없다.

## Requirements

### Functional

- `VisionTrainView`의 root surface와 hero/state/card anchor를 stable accessibility identifier로 고정한다.
- ready 상태에서 SharePlay, Voice Quick Entry, Exercise Form Guide, Spatial Muscle Map 카드 존재를 selector로 구분 가능하게 만든다.
- loading / unavailable / failed 상태를 각각 별도 state container identifier로 구분 가능하게 만든다.
- `todos/086-ready-p3-e2e-dunevision-train-view.md`를 실제 코드 기준 inventory로 채우고 완료 상태로 갱신한다.

### Non-functional

- child surface의 deep interaction selector 설계까지는 이번 범위에 포함하지 않는다.
- identifier는 `VisionSurfaceAccessibility` helper에 모아 drift를 줄인다.
- visionOS XCUITest harness 구축이나 3D chart window open verification은 deferred로 유지한다.

## Approach

기존 visionOS E2E backlog 패턴과 동일하게 `VisionSurfaceAccessibility`에 Train surface 상수를 추가하고, `VisionTrainView`에서 root/state/card/button anchor를 wiring한다. 이후 `VisionSurfaceAccessibilityTests`에 stability/uniqueness 테스트를 추가하고 TODO 문서를 같은 vocabulary로 업데이트한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| TODO 문서만 채운다 | 구현량 최소 | 코드 기준 selector가 없어 회귀 가치가 낮음 | 기각 |
| child card 파일마다 세부 AXID를 대량 추가한다 | 이후 deep automation에 유리할 수 있음 | 이번 TODO 범위를 넘고 diff가 커짐 | 기각 |
| shared helper + parent view wiring + 테스트 + TODO sync | 최소 변경으로 stable surface inventory 확보 | child interaction은 후속 TODO 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | modify | Train root/state/card/button selector helper 추가 |
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | modify | root, hero, state container, ready 카드, chart button에 accessibility identifier 연결 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | modify | Train selector mapping/uniqueness 회귀 테스트 추가 |
| `todos/086-ready-p3-e2e-dunevision-train-view.md` | move+modify | TODO 상태를 done으로 갱신하고 inventory를 코드 기준으로 기록 |
| `todos/021-ready-p2-e2e-phase0-page-backlog-index.md` | modify | backlog index에서 086 링크를 done 파일명으로 동기화 |

## Implementation Steps

### Step 1: Train selector inventory 정의

- **Files**: `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift`
- **Changes**: train root, hero card, open chart button, loading/unavailable/failed state, shareplay/voice/guide/muscle map 카드 identifier 추가
- **Verification**: `VisionSurfaceAccessibilityTests`에서 값과 uniqueness를 고정

### Step 2: VisionTrainView에 identifier 연결

- **Files**: `DUNEVision/Presentation/Activity/VisionTrainView.swift`
- **Changes**: root scroll surface, hero card, chart button, state container, ready 상태 child card wrapper에 accessibility identifier 부여
- **Verification**: `rg "vision-train-" DUNEVision/Presentation/Activity/VisionTrainView.swift`로 wiring 위치 확인

### Step 3: 테스트와 TODO 문서 동기화

- **Files**: `DUNETests/VisionSurfaceAccessibilityTests.swift`, `todos/086-ready-p3-e2e-dunevision-train-view.md`, `todos/021-ready-p2-e2e-phase0-page-backlog-index.md`
- **Changes**: selector stability test 추가, TODO 086을 done으로 갱신하고 entry/state/deferred lane을 코드 기준으로 기록, backlog index 링크 동기화
- **Verification**: 관련 테스트 통과, TODO 체크리스트 완료

## Edge Cases

| Case | Handling |
|------|----------|
| `loadState`가 `loading`, `unavailable`, `failed`로 바뀌며 ready 카드가 사라짐 | state별 container identifier를 별도로 두고 TODO에 assertion 범위를 분리 기록 |
| ready 상태 child card 내부가 향후 크게 바뀜 | 카드 내부 텍스트 대신 parent card container AXID만 root surface 범위로 assert |
| hero button이 chart3d window를 연다 | 버튼 selector 존재까지만 이번 범위에 포함하고 실제 openWindow/handoff는 deferred로 남김 |

## Testing Strategy

- Unit tests: `VisionSurfaceAccessibilityTests`에 Train selector mapping/uniqueness 추가
- Integration tests: 없음. visionOS XCUITest harness는 deferred 유지
- Manual verification: `scripts/build-ios.sh`, `swift test --filter VisionSurfaceAccessibilityTests` 또는 동등한 대상 테스트 실행

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| child card 구조 변경 후 TODO inventory가 stale 됨 | medium | medium | helper를 source of truth로 두고 테스트/문서를 같은 배치에서 갱신 |
| state별 AXID가 부족해 later harness에서 재작업 필요 | medium | low | loading/unavailable/failed를 각각 분리해 최소 state coverage 확보 |
| open chart button selector를 handoff assertion으로 오해할 수 있음 | low | medium | TODO의 deferred lane에 openWindow verification 제외를 명시 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: content/dashboard/chart3d surface에서 이미 같은 패턴이 검증됐고, 이번 변경은 Train root surface 한 화면의 selector inventory 고정에 한정되어 범위가 작고 명확하다.
