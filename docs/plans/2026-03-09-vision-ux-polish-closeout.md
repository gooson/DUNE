---
topic: visionOS UX polish closeout
date: 2026-03-09
status: approved
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-08-visionos-window-placement-planner.md
  - docs/solutions/general/2026-03-08-vision-pro-todo-state-reconciliation.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md
---

# Implementation Plan: visionOS UX polish closeout

## Context

`todos/022-done-p2-vision-ux-polish.md`로 닫아야 할 5B 구현이 TODO 상태만 뒤처진 채 남아 있다. 현재 코드 기준으로 `defaultWindowPlacement` planner, 관련 unit test, 대부분의 visionOS typography cleanup은 모두 들어가 있지만, `VisionSharePlayWorkoutCard`에 `.caption` 한 곳이 남아 있어 TODO를 그대로 닫으면 구현 상태와 문서가 다시 어긋난다.

또한 남은 검증 범위였던 spatial window placement의 실제 시각 확인은 아직 별도 visionOS UI harness 없이 자동화하기 어렵다. 기존 `087/088/089/090` TODO도 `openWindow`/window lifecycle 자동화는 deferred로 유지하고 있으므로, 이번 배치는 022의 구현 범위를 정직하게 닫고 runtime spatial verification은 후속 TODO로 분리하는 것이 맞다.

## Requirements

### Functional

- `DUNEVision`에 남아 있는 마지막 `.caption` 사용처를 `.callout` 이상으로 정리한다.
- `todos/022`를 `done` 상태로 전환하고, 구현 완료 근거와 후속 검증 분리 이유를 남긴다.
- spatial window placement의 simulator/device 시각 검증을 추적할 새 TODO를 추가한다.
- `todos/020`, `todos/023`의 메모를 `022 done -> runtime validation follow-up -> 023 advanced scope` 흐름으로 정리한다.

### Non-functional

- product code 변경은 typography 1건과 문서 정리에 한정한다.
- 실제로 수행하지 않은 visual verification을 완료처럼 기록하지 않는다.
- 기존 planner/test/build 흐름을 다시 실행해 현재 코드와 TODO 상태가 일치하는지 확인한다.

## Approach

이미 merge된 5B 구현을 다시 건드리지 않고, 남아 있는 typography drift 1건만 수정한다. 그 뒤 `022`는 "구현 phase 완료" TODO로 닫고, runtime spatial verification은 별도 TODO로 옮겨 backlog를 정합화한다.

이 접근은 두 가지 장점이 있다.

- main에 이미 있는 window placement planner + test를 source of truth로 인정하면서 TODO 상태를 실제 코드에 맞출 수 있다.
- 아직 없는 visionOS runtime harness 때문에 broad phase TODO가 오래 열려 있는 문제를 풀면서도, 시각 검증 자체는 독립 항목으로 추적할 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `022`를 계속 in-progress로 둔다 | visual verification 기준을 엄격히 유지 | 이미 ship된 구현 phase와 backlog 상태가 계속 어긋남 | 기각 |
| 후속 TODO 없이 `022`를 바로 done으로 바꾼다 | 가장 빠름 | runtime placement 검증 추적이 사라지고 사실상 누락된다 | 기각 |
| 잔여 `.caption` 수정 후 `022`를 닫고 runtime validation을 별도 TODO로 분리한다 | 구현 상태와 backlog를 동시에 정합화하고 미완료 검증도 보존 | TODO 1개가 추가된다 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-09-vision-ux-polish-closeout.md` | add | 이번 closeout 계획서 |
| `DUNEVision/Presentation/Activity/VisionSharePlayWorkoutCard.swift` | modify | 마지막 `.caption` 사용을 `.callout`로 상향 |
| `todos/022-done-p2-vision-ux-polish.md` | move/modify | 구현 완료 TODO로 전환하고 후속 검증 분리 메모 추가 |
| `todos/107-ready-p2-vision-window-placement-runtime-validation.md` | add | spatial placement simulator/device 시각 검증 후속 TODO |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | modify | 5B 종료 및 runtime validation follow-up 관계 반영 |
| `todos/023-in-progress-p2-vision-phase4-remaining.md` | modify | 5B 완료 후 advanced scope와 validation follow-up 경계를 명시 |

## Implementation Steps

### Step 1: Remove the last remaining visionOS `.caption`

- **Files**: `DUNEVision/Presentation/Activity/VisionSharePlayWorkoutCard.swift`
- **Changes**: participant phase badge typography를 `.callout.weight(.semibold)` 이상으로 상향한다.
- **Verification**: `rg "\\.font\\(\\.caption|\\.font\\(\\.caption2" DUNEVision -g '*.swift'` 결과 0건

### Step 2: Reconcile TODO state with shipped implementation

- **Files**: `todos/022...`, `todos/107...`, `todos/020...`, `todos/023...`
- **Changes**:
  - `022`를 `done` 파일명/상태로 전환하고 구현 근거(build/test/static verification)를 기록한다.
  - runtime spatial verification을 별도 TODO `107`로 생성해 simulator/device visual check scope를 옮긴다.
  - umbrella/next-phase TODO 메모를 새 흐름에 맞게 정리한다.
- **Verification**:
  - TODO 파일명과 frontmatter status 일치
  - `rg -n "022-(in-progress|done)|107-ready-p2-vision-window-placement-runtime-validation" todos`

### Step 3: Re-run quality checks against the current main-based implementation

- **Files**: existing code/tests/scripts only
- **Changes**: 없음. verification only
- **Verification**:
  - `scripts/build-ios.sh`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing DUNETests/VisionWindowPlacementPlannerTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`

## Edge Cases

| Case | Handling |
|------|----------|
| visionOS simulator/device visual verification를 이번 세션에서 자동화하지 못함 | `022` 완료 근거에 "구현 완료"와 "runtime validation 분리"를 분리 기록하고 새 TODO로 추적 |
| `VisionSharePlayWorkoutCard` 외에 숨은 `.caption` 사용처가 더 있음 | Step 1 verification grep으로 전수 확인 후 필요 시 같은 배치에서 정리 |
| DUNEVision build는 성공하지만 iOS build/test가 실패함 | broad repo health issue로 보고 closeout을 멈추고 실패 원인을 우선 수정 |

## Testing Strategy

- Unit tests: existing `VisionWindowPlacementPlannerTests` targeted rerun
- Integration tests: 없음. visionOS window lifecycle automation harness는 후속 TODO로 분리
- Manual verification: DUNEVision generic visionOS build 확인, runtime spatial arrangement visual check는 새 follow-up TODO에서 simulator/device로 수행
- Static verification: `rg "\\.font\\(\\.caption|\\.font\\(\\.caption2" DUNEVision -g '*.swift'`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| broad TODO를 닫는 과정에서 미수행 visual verification가 가려짐 | Medium | High | `022` 본문과 새 TODO `107`에 분리 이유와 남은 scope를 명시 |
| detached HEAD 상태에서 작업을 시작해 ship 단계가 막힘 | Medium | Medium | Work Setup에서 `codex/` prefix 작업 브랜치를 생성 |
| xcodebuild destination 이름이 로컬 simulator inventory와 다름 | Medium | Low | unit test command 실패 시 스크립트 또는 available simulator 기준 destination으로 조정 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 실제 product code 변경은 매우 작고, 핵심은 backlog/state reconciliation이다. 이미 main에 있는 planner/test/build 경로를 다시 검증하면 closeout 근거를 충분히 만들 수 있다. 유일한 외부 제약은 runtime spatial visual verification 자동화 부재인데, 이는 별도 TODO로 정직하게 분리할 수 있다.
