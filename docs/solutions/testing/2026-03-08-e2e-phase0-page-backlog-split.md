---
tags: [ui-test, e2e, backlog, todo, phase0, regression, watchos, visionos, widget]
category: testing
date: 2026-03-08
severity: important
related_files:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
  - docs/plans/2026-03-08-e2e-phase0-page-todo-split.md
  - todos/021-ready-p2-e2e-phase0-page-backlog-index.md
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
---

# Solution: E2E Phase 0 Page Backlog Split

## Problem

전체 화면 / 전체 타겟 E2E 전략은 브레인스토밍 문서에 정리되어 있었지만, 실제 실행 가능한 backlog는 여전히 한 덩어리였다. 이 상태에서는 `/plan`이나 `/work`가 특정 화면 하나를 바로 집어 실행하기 어렵고, must-have surface와 deferred target이 혼재되어 우선순위 판단도 느려진다.

### Symptoms

- 한 문서 안에 `DUNE`, `DUNEWatch`, `DUNEVision`, `DUNEWidget` surface가 모두 섞여 있었다.
- 개별 페이지 기준 후속 작업을 만들려면 다시 inventory를 수작업으로 분해해야 했다.
- TODO 시스템(`todos/NNN-STATUS-PRIORITY-description.md`)과 E2E inventory가 연결되지 않았다.

### Root Cause

Phase 0 inventory가 전략 문서로만 존재했고, page-level execution unit으로 분해되지 않았다. 즉, 회귀 surface 정의와 실제 작업 단위가 분리되어 있었다.

## Solution

브레인스토밍의 Product Surface Inventory를 source of truth로 삼아, page-level TODO backlog로 분리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `docs/plans/2026-03-08-e2e-phase0-page-todo-split.md` | 계획서 추가 | 번호 정책, 분리 기준, 검증 전략 고정 |
| `todos/021-ready-p2-e2e-phase0-page-backlog-index.md` | index 추가 | 전체 surface TODO를 target별로 탐색 가능하게 함 |
| `todos/022-*.md` ~ `todos/083-*.md` | must-have surface TODO 추가 | `DUNE` + `DUNEWatch` 회귀 작업을 page-level로 분해 |
| `todos/084-*.md` ~ `todos/095-*.md` | deferred surface TODO 추가 | `DUNEVision` + `DUNEWidget`를 후속 lane으로 분리 |
| `docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md` | Phase 0 artifact 섹션 추가 | 전략 문서와 backlog 진입점을 연결 |

### Key Code

```md
---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2 | p3
status: ready
created: 2026-03-08
updated: 2026-03-08
---

# E2E Surface: {Target} {Surface}
```

핵심은 모든 surface TODO가 동일한 frontmatter와 naming convention을 따르도록 한 점이다. 이렇게 하면 후속 `/plan`, `/work`, `/review`가 어느 surface 문서를 읽더라도 같은 구조로 시작할 수 있다.

## Prevention

E2E 전략 문서를 만들 때는 inventory 단계에서 바로 page-level backlog로 이어지게 설계한다.

### Checklist Addition

- [ ] 브레인스토밍에 surface inventory가 생기면 바로 `todos/` backlog로 분해할 것
- [ ] must-have target과 deferred target의 priority를 명시적으로 나눌 것
- [ ] index 문서를 만들어 target/section별 진입점을 남길 것
- [ ] TODO 번호 범위와 후속 시작 번호를 문서에 적을 것

### Rule Addition (if applicable)

새 규칙 파일 추가는 보류. 동일한 E2E inventory 작업이 생기면 이 solution 문서를 우선 참조한다.

## Lessons Learned

회귀 전략은 큰 문서 한 장으로는 실행력이 떨어진다. page-level backlog로 쪼개야 PR gate, nightly, deferred lane이 실제 작업 큐로 바뀌고, 이후 자동화 구현도 surface 기준으로 병렬화할 수 있다.
