---
topic: vision-todo-closeout
date: 2026-03-22
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-08-vision-pro-todo-state-reconciliation.md
  - docs/solutions/testing/2026-03-16-vision-window-placement-smoke.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-vision-pro-features.md
---

# Implementation Plan: Vision Pro TODO Closeout

## Context

`todos/active/vision`에는 현재 `020`, `023`, `144` 세 개의 Vision Pro backlog가 남아 있다. 이 중 `144`는 no-anchor utility-panel fallback을 실제로 재현해 증빙을 남겨야 닫을 수 있는 검증 TODO다. 반면 `020`과 `023`은 shipped foundation과 future capability-heavy scope가 섞인 umbrella 문서라, active backlog로 남겨 두면 지금 당장 해야 할 일과 장기 탐색 범위를 구분하기 어렵다.

## Requirements

### Functional

- no-anchor 상태에서 `VisionWindowPlacementPlanner`의 `.utilityPanel` fallback을 재현 가능한 smoke 경로로 검증한다.
- simulator에서 screenshot/note artifact를 남길 수 있어야 한다.
- `020`, `023`, `144`의 상태와 메모가 현재 shipped scope와 일치해야 한다.
- `141`로 남은 stale reference를 실제 파일 번호 `144`로 정리한다.

### Non-functional

- window placement smoke 로직은 기존 planner 옆의 pure configuration 패턴을 유지한다.
- visionOS 전용 app wiring은 `DUNEVision/`에 두고, shared state/config parsing은 `DUNE/Presentation/Vision/`에 둔다.
- TODO closeout은 "문서만 done"이 아니라 코드/검증/근거가 함께 남아야 한다.

## Approach

`VisionWindowPlacementSmokeConfiguration`를 primary smoke와 no-anchor smoke를 모두 표현할 수 있게 확장한다. `VisionContentView`는 no-anchor mode에서 settings utility window를 먼저 열고 main window를 dismiss해 anchor-less 상태를 만든다. `VisionSettingsView`는 같은 smoke mode를 감지해 utility panel context에서 fallback 대상 window를 자동 오픈한다. 이후 smoke script를 no-anchor 모드까지 지원하게 바꾸고 실제 artifact를 생성한다.

TODO 정리는 two-track으로 수행한다. `144`는 새 smoke artifact를 근거로 `done`으로 닫고, `020`/`023`은 shipped foundation과 future exploration 경계를 note로 명시한 뒤 active umbrella에서 내린다. 장기 capability scope는 TODO blocking item이 아니라 roadmap note로 남긴다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `144`만 닫고 `020/023`은 그대로 유지 | 구현 범위가 작다 | active queue에 stale umbrella가 계속 남아 backlog 신뢰도가 떨어진다 | Rejected |
| `020/023`을 새 하위 TODO로 쪼개 active backlog를 유지 | future scope가 더 구체적이다 | "active vision TODO zero"를 달성하지 못하고, 실기기 의존 scope를 현재 작업 큐에 계속 남긴다 | Rejected |
| no-anchor smoke 구현 + stale umbrella closeout 동시 진행 | 코드/검증과 backlog 정합성을 함께 맞출 수 있다 | 문서 판단 근거를 명확히 남겨야 한다 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift` | modify | smoke mode/launch argument parsing 확장 |
| `DUNEVision/App/VisionContentView.swift` | modify | no-anchor smoke start sequence와 main window dismiss 처리 |
| `DUNEVision/Presentation/Settings/VisionSettingsView.swift` | modify | utility panel 기준 fallback auto-open smoke continuation |
| `DUNETests/VisionWindowPlacementPlannerTests.swift` | modify | no-anchor smoke configuration regression coverage 추가 |
| `scripts/vision-window-placement-smoke.sh` | modify | no-anchor smoke launch option + artifact note 확장 |
| `todos/active/vision/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | modify | umbrella closeout note와 final status 정리 |
| `todos/active/vision/023-in-progress-p2-vision-phase4-remaining.md` | modify | advanced roadmap note 정리 및 active queue exit |
| `todos/active/vision/144-ready-p3-vision-window-placement-no-anchor-fallback.md` | modify | verification result 반영 후 done 전환 |
| `todos/done/107-done-p2-vision-window-placement-runtime-validation.md` | modify | stale `141` reference를 `144`로 교정 |
| `docs/solutions/testing/2026-03-16-vision-window-placement-smoke.md` | modify or add | no-anchor smoke 확장과 artifact 경로 기록 |

## Implementation Steps

### Step 1: Extend no-anchor smoke path

- **Files**: `VisionWindowPlacementPlanner.swift`, `VisionContentView.swift`, `VisionSettingsView.swift`
- **Changes**:
  - smoke configuration에 mode를 추가한다.
  - no-anchor mode에서는 settings window를 먼저 열고 main window를 dismiss한다.
  - settings window가 fallback 대상 window를 자동으로 열도록 연결한다.
- **Verification**:
  - 관련 symbol/typecheck 확인
  - config parsing/unit tests 추가

### Step 2: Update script and generate artifact

- **Files**: `scripts/vision-window-placement-smoke.sh`
- **Changes**:
  - no-anchor smoke 실행 옵션을 추가한다.
  - note 파일에 smoke mode와 launch args를 기록한다.
- **Verification**:
  - script 실제 실행
  - screenshot + note artifact 생성 확인

### Step 3: Reconcile active vision TODOs

- **Files**: `todos/active/vision/020-*.md`, `todos/active/vision/023-*.md`, `todos/active/vision/144-*.md`, `todos/done/107-*.md`, 관련 solution doc
- **Changes**:
  - `144`에 verification result를 기록하고 `done/`으로 이동한다.
  - `020`, `023`은 stale umbrella closeout note와 future-scope rationale를 남기고 `done/`으로 이동한다.
  - `141` reference를 `144`로 통일한다.
- **Verification**:
  - `todos/active/vision`가 비어 있는지 확인
  - `rg "todos/141"` 결과가 0인지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| main window dismiss 후 follow-up task가 취소됨 | settings window 쪽에서 continuation을 수행해 main window lifecycle에 덜 의존하게 만든다 |
| simulator timing 차이로 window가 모두 열리기 전에 screenshot 캡처 | script wait time을 option/env로 유지하고 note에 실제 wait 값을 남긴다 |
| no-anchor fallback이 여전히 시각적으로 불명확 | screenshot 외에 note에 열린 window IDs와 mode를 남겨 재현성을 높인다 |
| umbrella closeout 판단이 과도하게 보일 위험 | 기존 shipped solution docs와 TODO 메모를 근거로 why-now를 문서에 명시한다 |

## Testing Strategy

- Unit tests: `VisionWindowPlacementPlannerTests`에서 no-anchor smoke configuration parsing 검증
- Integration tests: 없음. visionOS runtime smoke script로 대체
- Manual verification:
  - `scripts/vision-window-placement-smoke.sh`
  - `scripts/vision-window-placement-smoke.sh --no-anchor`
  - artifact screenshot/note 확인
  - `ls todos/active/vision`
  - `rg "todos/141" .`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `dismissWindow()` 이후 no-anchor continuation이 실행되지 않음 | medium | high | continuation을 settings window 쪽 task로 이동하고 충분한 delay를 둔다 |
| simulator multi-window screenshot가 환경마다 다름 | medium | medium | note에 mode/window order를 남기고 wait time을 조정 가능하게 유지한다 |
| active umbrella closeout이 미래 scope 손실처럼 보임 | low | medium | future capability는 TODO note와 brainstorm/solution reference로 명시해 기록을 유지한다 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: smoke path 확장은 기존 primary window placement automation 패턴을 재사용할 수 있어 구현 난도는 낮다. 다만 `dismissWindow()`와 utility-panel continuation의 실제 simulator 동작은 런타임 확인이 필요해 medium으로 둔다.
