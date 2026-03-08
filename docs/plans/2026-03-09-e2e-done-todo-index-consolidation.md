---
topic: e2e done todo index consolidation
date: 2026-03-09
status: approved
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Done TODO Index Consolidation

## Context

`todos/101-ready-p2-e2e-phase0-page-backlog-index.md`는 원래 phase 0 surface backlog의 진입점 역할이지만, 현재는 `ready`와 `done` 항목이 섞여 있고 일부 iOS surface는 이미 `done`으로 rename된 파일명을 아직 반영하지 못했다. 그 결과 active backlog를 볼 때 실제 남은 작업과 완료 기록이 한 문서에 섞이고, 깨진 링크도 남아 탐색성이 떨어진다.

## Requirements

### Functional

- active `e2e` backlog index는 아직 열려 있는 surface만 보여줘야 한다.
- 완료된 `e2e` surface는 한 곳에서 묶어 볼 수 있어야 한다.
- 개별 `done` TODO 문서는 삭제하지 않고 그대로 유지해야 한다.
- `DUNE`, `DUNEWatch`, `DUNEVision` 완료 surface 링크가 실제 파일명과 일치해야 한다.

### Non-functional

- 기존 TODO numbering/history는 유지한다.
- `todo-conventions.md`의 `done` 기록 유지 규칙을 어기지 않는다.
- 문서만 변경하고 앱 코드나 테스트 코드는 건드리지 않는다.

## Approach

기존 `todos/101-...`는 active backlog index로 재정의하고, 새 `done` index TODO를 하나 추가해 완료 surface를 target별로 묶는다. 이렇게 하면 active queue와 historical record를 분리하면서도 개별 완료 문서의 세부 inventory는 그대로 보존할 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 `done` TODO를 삭제하고 통합 문서 하나만 남긴다 | 파일 수가 가장 많이 줄어든다 | `done` 기록 유지 규칙을 위반하고 개별 surface 히스토리가 사라진다 | Rejected |
| 기존 backlog index 하나에 `ready`/`done`을 모두 유지하되 링크만 고친다 | 변경 파일 수가 가장 적다 | active backlog 탐색성이 계속 나쁘고 문서 목적이 모호하다 | Rejected |
| active backlog index와 completed surface index를 분리한다 | 규칙을 지키면서 현재 작업 큐와 완료 기록을 모두 빠르게 찾을 수 있다 | 인덱스 문서가 하나 늘어난다 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-09-e2e-done-todo-index-consolidation.md` | add | 이번 작업의 구현 계획서 |
| `todos/101-ready-p2-e2e-phase0-page-backlog-index.md` | modify | active backlog만 남기고 done 항목/깨진 링크를 정리 |
| `todos/107-done-p2-e2e-phase0-completed-surface-index.md` | add | 완료된 e2e surface를 target별로 묶는 인덱스 |
| `docs/solutions/testing/2026-03-09-e2e-done-todo-index-consolidation.md` | add | backlog와 completed index 분리 패턴 문서화 |

## Implementation Steps

### Step 1: Active backlog index 정리

- **Files**: `todos/101-ready-p2-e2e-phase0-page-backlog-index.md`
- **Changes**:
  - `done` 상태인 surface 링크를 active backlog에서 제거한다.
  - 섹션별로 아직 `ready`인 surface만 남긴다.
  - 완료 항목은 새 completed index로 이동했음을 notes에 남긴다.
- **Verification**: `rg -n "043-(ready|done)-p2-e2e|044-(ready|done)-p2-e2e|045-(ready|done)-p2-e2e|065-(ready|done)-p2-e2e|066-(ready|done)-p2-e2e|067-(ready|done)-p2-e2e|068-(ready|done)-p2-e2e|069-(ready|done)-p2-e2e|070-(ready|done)-p2-e2e|071-(ready|done)-p2-e2e|072-(ready|done)-p2-e2e|073-(ready|done)-p2-e2e|074-(ready|done)-p2-e2e|075-done-p2-e2e|076-done-p2-e2e|077-done-p2-e2e|078-done-p2-e2e|079-done-p2-e2e|080-done-p2-e2e|081-done-p2-e2e|082-done-p2-e2e|083-done-p2-e2e|084-done-p3-e2e|085-done-p3-e2e|086-done-p3-e2e|087-done-p3-e2e|088-done-p3-e2e|089-done-p3-e2e|090-done-p3-e2e|091-done-p3-e2e" todos/101-ready-p2-e2e-phase0-page-backlog-index.md`

### Step 2: Completed surface index 추가

- **Files**: `todos/107-done-p2-e2e-phase0-completed-surface-index.md`
- **Changes**:
  - `DUNE`, `DUNEWatch`, `DUNEVision`의 완료 surface 30건을 target별로 링크 정리한다.
  - 문서 상단에 이 인덱스의 목적과 유지 원칙을 적는다.
- **Verification**: `rg -n "043-done|074-done|075-done|083-done|084-done|091-done" todos/107-done-p2-e2e-phase0-completed-surface-index.md`

### Step 3: Solution 문서화

- **Files**: `docs/solutions/testing/2026-03-09-e2e-done-todo-index-consolidation.md`
- **Changes**:
  - backlog index와 completed index를 분리한 이유를 기록한다.
  - `done` TODO를 직접 합치지 않고 index로 묶는 패턴을 재사용 가능한 해결책으로 남긴다.
- **Verification**: `ls -la docs/solutions/testing/2026-03-09-e2e-done-todo-index-consolidation.md`

## Edge Cases

| Case | Handling |
|------|----------|
| 일부 surface는 backlog 문서엔 `ready` 링크로 남아 있지만 실제 파일은 `done`으로 rename돼 있음 | active backlog에서는 제거하고 completed index에서 실제 `done` 파일명으로 다시 링크한다 |
| 후속에 `DUNEWidget`까지 완료되면 index가 더 커질 수 있음 | target별 섹션 구조를 유지해 동일 패턴으로 추가한다 |
| 개별 완료 문서 내용이 서로 다른 길이를 가짐 | completed index는 링크 모음만 제공하고 상세 내용은 각 TODO에서 유지한다 |

## Testing Strategy

- Unit tests: 없음. 문서 구조 변경이다.
- Integration tests:
  - `rg -n "043-(ready|done)-p2-e2e|044-(ready|done)-p2-e2e|045-(ready|done)-p2-e2e|065-(ready|done)-p2-e2e|066-(ready|done)-p2-e2e|067-(ready|done)-p2-e2e|068-(ready|done)-p2-e2e|069-(ready|done)-p2-e2e|070-(ready|done)-p2-e2e|071-(ready|done)-p2-e2e|072-(ready|done)-p2-e2e|073-(ready|done)-p2-e2e|074-(ready|done)-p2-e2e|075-done-p2-e2e|076-done-p2-e2e|077-done-p2-e2e|078-done-p2-e2e|079-done-p2-e2e|080-done-p2-e2e|081-done-p2-e2e|082-done-p2-e2e|083-done-p2-e2e|084-done-p3-e2e|085-done-p3-e2e|086-done-p3-e2e|087-done-p3-e2e|088-done-p3-e2e|089-done-p3-e2e|090-done-p3-e2e|091-done-p3-e2e" todos/101-ready-p2-e2e-phase0-page-backlog-index.md`
  - `rg -n "043-done|074-done|075-done|083-done|084-done|091-done" todos/107-done-p2-e2e-phase0-completed-surface-index.md`
- Manual verification: `todos/101`은 open backlog만 보여주고, `todos/107`은 done surface만 모아 보여주는지 눈으로 확인한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 다른 문서가 backlog index를 “전체 inventory”로 가정하고 있을 수 있음 | Medium | Low | notes에 completed index 경로를 명시해 탐색 경로를 유지한다 |
| 새 done index 번호가 후속 TODO 번호 계획과 충돌할 수 있음 | Low | Low | 현재 최고 번호 다음(`107`)만 사용하고 기존 번호는 건드리지 않는다 |
| 문서만 분리하고 related solution을 남기지 않으면 같은 고민이 반복될 수 있음 | Medium | Low | solution 문서로 분리 이유와 유지 규칙을 남긴다 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 backlog split 패턴이 이미 있고, 이번 작업은 문서 계층을 active/done으로 한 단계 더 정리하는 수준이라 구현 리스크가 낮다.
