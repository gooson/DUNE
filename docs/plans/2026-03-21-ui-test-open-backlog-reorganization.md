---
topic: ui-test-open-backlog-reorganization
date: 2026-03-21
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
  - docs/solutions/testing/2026-03-09-e2e-done-todo-index-consolidation.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: UI Test Open Backlog Reorganization

## Context

`todos/active/e2e/101-ready-p2-e2e-phase0-page-backlog-index.md`는 open surface를 target별 단순 목록으로 보여줬다. 현재 남아 있는 surface가 모두 `DUNE Activity / Exercise`에 몰린 시점에서는 이 방식이 "무엇이 남았는가"는 보여주지만 "어떤 순서로 구현해야 하는가"는 잘 드러내지 못한다.

남은 20건은 실제로는 독립적인 20개 화면이 아니라 `root route`, `authoring/detail`, `manual session`, `template`, `compound`, `cardio`, `specialized deep link`로 다시 묶이는 backlog다. 문서를 이 구조로 재정렬하면 `/plan`이나 후속 구현 batch가 surface 번호가 아니라 flow 단위로 바로 시작할 수 있다.

## Requirements

### Functional

- open backlog index가 현재 남은 UI test TODO 20건을 빠짐없이 포함해야 한다.
- 같은 parent flow를 공유하는 surface를 execution wave로 다시 묶어야 한다.
- completed surface index는 그대로 두고, open backlog 진입점만 더 실행 가능하게 바꿔야 한다.

### Non-functional

- 개별 TODO 파일을 source of truth로 유지해야 한다.
- 파일 번호 정책이나 done/archive 구조는 바꾸지 않는다.
- 문서 재정렬만 수행하고 surface 상태 자체는 변경하지 않는다.

## Approach

open backlog를 "target별 목록"에서 "flow 기반 execution waves"로 재구성한다.

### Chosen Structure

1. `Wave 1`: root entry and shared navigation
2. `Wave 2`: authoring, detail, and management
3. `Wave 3`: manual workout session flow
4. `Wave 4`: template workout flow
5. `Wave 5`: compound workout flow
6. `Wave 6`: cardio session flow

이 구조는 parent surface를 먼저 닫고 child session을 뒤로 미루는 현재 코드 구조와 맞는다. 특히 `048 -> 049 -> 050`, `053 -> 054 -> 055 -> 056`, `057 -> 058`, `059 -> 060 -> 061`처럼 helper와 seeded fixture를 재사용할 수 있는 묶음이 분명하다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 파일 번호 순으로 유지 | 기존 문맥과 가장 비슷함 | 실행 순서와 parent-child 관계가 드러나지 않음 | 기각 |
| target별 대분류만 유지 | 문서가 짧고 단순함 | 현재 open item이 모두 같은 target이라 정보 밀도가 낮음 | 기각 |
| flow 기반 wave로 재구성 | 구현 batch, helper 재사용, closeout 순서가 바로 보임 | 문서 구조를 다시 익혀야 함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `todos/active/e2e/101-ready-p2-e2e-phase0-page-backlog-index.md` | modify | open backlog를 flow 기반 execution wave 구조로 재작성 |
| `docs/plans/2026-03-21-ui-test-open-backlog-reorganization.md` | add | 재분류 기준과 closeout 순서를 남기는 계획 문서 |

## Implementation Steps

### Step 1: Reconfirm the open surface set

- `todos/active/e2e`에서 현재 open surface 20건을 다시 확인한다.
- index 문서 `101` 자체는 count에서 제외하고 개별 surface 문서만 목록으로 본다.

### Step 2: Group the backlog by reusable flow

- root route와 shared helper를 가장 먼저 두는 `Wave 1`을 만든다.
- detail/form/management surface는 `Wave 2`로 묶는다.
- manual/template/compound/cardio session은 parent-child 순서를 유지해 별도 wave로 분리한다.

### Step 3: Rewrite the index as an execution entry point

- 기존 target별 단순 목록을 제거한다.
- 현재 열려 있는 범위, suggested closeout order, shared prerequisites를 같이 적는다.
- done index 경로는 그대로 유지해 open/completed 분리를 보존한다.

## Resulting Backlog Shape

| Wave | Scope | Surfaces |
|------|-------|----------|
| 1 | Root entry / shared navigation | 051, 048, 053, 057, 059, 062, 064 |
| 2 | Authoring / detail / management | 042, 046, 047, 052, 054, 063 |
| 3 | Manual workout session | 049, 050 |
| 4 | Template workout session | 055, 056 |
| 5 | Compound workout session | 058 |
| 6 | Cardio workout session | 060, 061 |

## Verification

- open backlog count가 여전히 20건인지 확인한다.
- `101`이 completed surface를 다시 나열하지 않는지 확인한다.
- 문서만 바뀌고 개별 surface 상태나 파일명은 바뀌지 않았는지 확인한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| specialized route를 잘못 root wave에 섞어 흐름이 모호해짐 | low | medium | `062`, `064`를 deep link/failure route로 명시 |
| 문서가 너무 요약돼 개별 surface 정보가 사라짐 | low | medium | source of truth는 계속 개별 TODO 문서로 유지 |
| done index와 역할이 다시 겹침 | low | medium | `101`은 open execution queue, `107`은 completed archive로 역할을 분리 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 open surface가 모두 하나의 target/feature cluster에 몰려 있어 flow 기반 재분류 기준이 명확하다. 개별 TODO나 done index를 건드리지 않고 진입 문서만 재작성하는 작업이라 구조적 위험도 낮다.
