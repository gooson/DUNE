---
topic: vision-pro-shareplay-workout-board-foundation
date: 2026-03-08
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
  - docs/solutions/architecture/2026-03-08-vision-pro-voice-workout-entry-foundation.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-vision-pro-features.md
  - docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md
---

# Implementation Plan: Vision Pro SharePlay Workout Board Foundation

## Context

`todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md`의 남은 핵심 범위는 `G1 Shared Workout Space`다. 하지만 brainstorm에 적힌 full scope는 SharePlay, SharedWorldAnchors, multi-user spatial alignment, health comparison까지 포함해 한 배치에서 닫기에는 너무 크다. 반면 Apple GroupActivities는 visionOS window를 함께 배치하고, 참가자 간 lightweight state sync를 제공할 수 있으므로, 이번 배치에서는 **SharePlay 세션 시작/참여 + 실시간 set/rep board**를 먼저 ship 가능한 foundation으로 정의한다.

## Requirements

### Functional

- Vision Pro `Train` 탭에서 SharePlay workout session을 시작하거나 기존 세션에 참여할 수 있어야 한다.
- 각 참여자는 자신의 현재 exercise / set / rep / status를 업데이트할 수 있어야 한다.
- 업데이트는 다른 참여자 화면에 실시간으로 반영되어 shared workout board 형태로 보여야 한다.
- 늦게 들어온 참여자도 현재 board 상태를 받을 수 있어야 한다.
- SharePlay를 사용할 수 없는 환경에서는 안내 메시지를 보여주고 feature를 안전하게 비활성화해야 한다.

### Non-functional

- session orchestration과 state reduction은 shared `Presentation/Vision` layer에 두고 테스트 가능해야 한다.
- UI는 visionOS 기존 Train 탭 material/card 패턴을 유지한다.
- 새 사용자 대면 문자열은 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja로 추가한다.
- 새 상태/메시지 로직은 `DUNETests`로 고정한다.

## Approach

`GroupActivity`와 `GroupSessionMessenger`를 감싸는 shared view model을 `DUNE/Presentation/Vision`에 추가한다. ViewModel은 세션 lifecycle 관찰, local participant state 변경, remote participant state merge, late-join replay를 담당하고, `DUNEVision`에는 이 상태를 렌더링하고 버튼 입력만 전달하는 전용 card view를 둔다.

full `SharedWorldAnchors`는 이번 배치에서 구현하지 않는다. 대신 Apple이 제공하는 window-based SharePlay 배치를 사용해 foundation을 닫고, spatial anchor alignment와 richer 3D placement는 후속 TODO로 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Full G1 with `SharedWorldAnchors` in one batch | TODO 원문 범위를 한 번에 충족 | 실기기 검증 의존이 크고 API/UX 범위가 과도함 | 기각 |
| SharePlay foundation with realtime workout board | 실제 social behavior를 ship 가능, 테스트 가능, 기존 Train 탭에 자연스럽게 결합 | anchor-based spatial sync는 후속으로 남음 | 채택 |
| TODO 020은 문서만 갱신하고 구현 보류 | 리스크 최소 | 사용자 요청인 “진행”을 충족하지 못함 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Vision/VisionSharePlayWorkoutViewModel.swift` | add | SharePlay session lifecycle + participant board state 관리 |
| `DUNEVision/Presentation/Activity/VisionSharePlayWorkoutCard.swift` | add | Train 탭 SharePlay board UI |
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | modify | 새 SharePlay card를 Train flow에 삽입 |
| `DUNE/project.yml` | modify | GroupActivities dependency / group-session entitlement wiring |
| `DUNEVision/Resources/DUNEVision.entitlements` | modify | group-session entitlement 반영 |
| `Shared/Resources/Localizable.xcstrings` | modify | SharePlay UI copy 추가 |
| `DUNETests/VisionSharePlayWorkoutViewModelTests.swift` | add | lifecycle / merge / replay / fallback 테스트 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | modify | G1 foundation 진행 현황 반영 |
| `todos/023-ready-p2-vision-phase4-remaining.md` | modify | anchor-based advanced scope가 남았음을 명시 |

## Implementation Steps

### Step 1: Build shared SharePlay state layer

- **Files**: `DUNE/Presentation/Vision/VisionSharePlayWorkoutViewModel.swift`, `DUNE/project.yml`, `DUNEVision/Resources/DUNEVision.entitlements`
- **Changes**:
  - `GroupActivity` 정의
  - participant workout state/message 모델 정의
  - session observe/start/join/send/replay 로직 구현
  - framework + entitlement wiring 추가
- **Verification**:
  - view model unit tests로 local update, remote merge, late join replay, unavailable state 확인

### Step 2: Add visionOS Train card UI

- **Files**: `DUNEVision/Presentation/Activity/VisionSharePlayWorkoutCard.swift`, `DUNEVision/Presentation/Activity/VisionTrainView.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - SharePlay start/join CTA, local progress controls, participant board UI 추가
  - unavailable / idle / active states에 맞는 localized copy 추가
  - 기존 Train 탭 card stack에 통합
- **Verification**:
  - build 통과
  - card 상태 전환이 view model public API와 맞는지 확인

### Step 3: Update documentation and TODO state

- **Files**: `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md`, `todos/023-ready-p2-vision-phase4-remaining.md`
- **Changes**:
  - 이번 배치가 G1 foundation임을 기록
  - `SharedWorldAnchors`/advanced spatial sync는 remaining scope로 재기록
- **Verification**:
  - TODO 상태가 실제 ship 범위와 일치하는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| GroupActivities unavailable on simulator/device | feature 비활성 + 안내 copy 표시 |
| user starts SharePlay before session activation succeeds | pending/failed state 메시지로 전환 |
| participant leaves session | board에서 해당 participant를 제거 |
| late joiner misses previous incremental messages | active participant change 시 latest local state 재전송 |
| participant name unavailable | `You`, `Participant 2` 같은 generic label 사용 |

## Testing Strategy

- Unit tests: view model session state, local progress mutation, remote message merge, active participant replay trigger
- Integration tests: `swift test`/`xcodebuild test` 수준에서 `DUNETests` 실행
- Manual verification: visionOS target build 후 SharePlay unavailable/idle UI 확인, 실제 multi-user SharePlay는 실기기 후속 검증으로 기록

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| GroupActivities API usage가 current SDK와 일부 다를 수 있음 | medium | high | Apple docs 기준으로 최소 surface만 사용하고 build로 즉시 검증 |
| simulator에서 SharePlay fully verify 불가 | high | medium | unit test로 reduction logic 고정, 실기기 검증은 TODO에 명시 |
| shared source를 DUNE target에도 포함하면서 iOS build 영향 가능 | medium | medium | framework dependency를 DUNE target에도 추가하고 iOS unit tests로 확인 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 architecture 패턴과 잘 맞고 testable scope로 줄였지만, GroupActivities wiring은 build-time 검증이 필수이며 multi-user runtime 검증은 실기기 의존성이 남는다.
