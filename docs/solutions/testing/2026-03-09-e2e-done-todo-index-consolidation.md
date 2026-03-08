---
tags: [ui-test, e2e, todo, backlog, done, archive, index, regression]
category: testing
date: 2026-03-09
severity: important
related_files:
  - docs/plans/2026-03-09-e2e-done-todo-index-consolidation.md
  - todos/101-ready-p2-e2e-phase0-page-backlog-index.md
  - todos/107-done-p2-e2e-phase0-completed-surface-index.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
---

# Solution: E2E Done TODO Index Consolidation

## Problem

phase 0 `e2e` surface backlog가 진행되면서 `todos/101-ready-p2-e2e-phase0-page-backlog-index.md` 한 문서에 open backlog와 completed record가 함께 쌓였다. 이 상태에서는 "지금 남은 작업"을 빠르게 훑기 어렵고, 일부 iOS surface는 이미 `done`으로 rename된 실제 파일명과 index 링크가 어긋나기 시작했다.

### Symptoms

- active backlog index에 `ready`와 `done` surface가 섞여 있었다.
- `043`~`045`, `065`~`074` 같은 surface는 실제론 완료됐는데 backlog index에는 옛 `ready` 링크가 남아 있었다.
- watchOS/visionOS는 done 파일명으로 링크되고 iOS 일부는 old ready 링크가 남아 있어 index 정책이 일관되지 않았다.

### Root Cause

초기 split 작업은 page-level TODO를 만드는 데 집중했고, 완료 이후의 보관 전략은 별도 문서로 분리하지 않았다. 그 결과 backlog index가 "실행 큐"와 "완료 기록"을 동시에 맡으면서 목적이 모호해졌다.

## Solution

active backlog index와 completed surface index를 분리했다. 핵심은 개별 `done` TODO를 삭제하지 않고 그대로 유지하면서, open queue만 보는 진입점과 완료 기록만 모아 보는 진입점을 나눈 것이다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `docs/plans/2026-03-09-e2e-done-todo-index-consolidation.md` | 계획서 추가 | active/done 분리 원칙, 번호 정책, 검증 방법을 먼저 고정하기 위해 |
| `todos/101-ready-p2-e2e-phase0-page-backlog-index.md` | open backlog 전용으로 정리 | 남은 작업만 빠르게 탐색할 수 있게 하기 위해 |
| `todos/107-done-p2-e2e-phase0-completed-surface-index.md` | completed index 추가 | 완료 surface를 target별로 한곳에서 찾을 수 있게 하기 위해 |

### Key Code

```md
# E2E Phase 0 Open Page Backlog Index

이 문서는 아직 열려 있는 phase 0 `e2e` surface만 관리한다.
완료된 surface 기록은 [107 E2E Phase 0 Completed Surface Index](107-done-p2-e2e-phase0-completed-surface-index.md)로 분리했다.
```

핵심은 `done` surface를 한 문서에 다시 풀어쓰는 것이 아니라, 개별 완료 TODO를 source of truth로 유지한 채 index만 분리한 점이다. 이렇게 하면 완료 문서의 세부 inventory와 PR gate 기록은 보존되고, active backlog 탐색도 다시 단순해진다.

## Prevention

surface backlog처럼 시간이 지나며 `ready`와 `done`이 섞이는 문서는 "실행 큐"와 "기록 아카이브"를 분리한다.

### Checklist Addition

- [ ] backlog index가 open item만 보여주는지 확인할 것
- [ ] completed item은 개별 `done` TODO를 유지한 채 별도 index에 모을 것
- [ ] rename 이후 stale `ready` 링크가 index에 남지 않았는지 `rg`로 확인할 것
- [ ] 새 completed index를 만들면 active backlog notes에 경로를 남길 것

### Rule Addition (if applicable)

새 규칙 파일 추가는 보류한다. 동일한 `todo` clutter 패턴이 반복되면 `todo-conventions.md` 또는 별도 backlog indexing 규칙으로 승격할 수 있다.

## Lessons Learned

`done` TODO를 직접 합치거나 삭제하면 기록성이 약해지고, 그대로 backlog에 쌓아두면 실행성이 떨어진다. active index와 completed index를 분리하면 두 요구를 동시에 만족시킬 수 있다.
