---
tags: [run-skill, ship-skill, pipeline, non-interactive, automation]
category: general
date: 2026-03-04
severity: important
related_files:
  - .claude/skills/run/SKILL.md
  - .claude/skills/ship/SKILL.md
  - CLAUDE.md
related_solutions:
  - docs/solutions/architecture/2026-02-16-agent-pipeline-integration.md
  - docs/solutions/general/2026-02-28-rename-lfg-to-run.md
---

# Solution: Run Pipeline Ship Completion Hardening

## Problem

`/run`은 전체 자동 파이프라인을 선언하지만, 실제 마지막 단계인 `/ship`이 미커밋 변경에서 사용자 선택을 요구해 파이프라인이 중단되는 경우가 있었다.

### Symptoms

- `/run` 실행 중 ship 단계에서 질문 분기 발생
- 자동 실행 문구와 실제 동작 간 불일치
- PR 생성 전 단계에서 흐름 중단

### Root Cause

`run`과 `ship` 간 인터페이스 계약이 일치하지 않았다. `run`은 non-interactive를 전제했지만 `ship`은 interactive fallback을 기본값으로 유지했다.

## Solution

`run`에 pre-ship gate를 추가하고, `ship` 기본 정책을 non-interactive로 바꿔 두 스킬 계약을 동기화했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `.claude/skills/run/SKILL.md` | Phase 5.5(Pre-Ship Finalization) 추가 | ship 진입 전 clean/auth/diff 조건 보장 |
| `.claude/skills/run/SKILL.md` | Phase 6을 non-interactive `/ship` 호출로 명시 | 단계 간 계약 일치 |
| `.claude/skills/ship/SKILL.md` | 미커밋 변경 처리 자동화(commit -> stash) | 사용자 입력 없이 진행 |
| `.claude/skills/ship/SKILL.md` | pending checks 재시도/무변경 종료 경로 추가 | 불필요 중단 감소 |

### Key Code

```md
/run Phase 5.5
- clean worktree 강제
- upstream/gh auth 확인
- main...HEAD diff 0이면 ship 생략

/ship Step 1
- git add -A && git commit ...
- 실패 시 git stash push -u ...
```

## Prevention

run이 하위 스킬을 호출할 때, 하위 스킬의 기본 동작이 interactive인지 non-interactive인지 항상 명시적으로 고정한다.

### Checklist Addition

- [ ] 상위 자동 파이프라인(`run`)과 하위 실행기(`ship`)의 interaction mode가 동일한가?
- [ ] ship 진입 전 clean worktree/auth/diff gate가 정의되어 있는가?

### Rule Addition (if applicable)

즉시 별도 rules 파일로 승격하지 않고, CLAUDE.md Correction Log 프로세스 항목으로 우선 기록한다.

## Lessons Learned

자동화 파이프라인의 실패는 기능 로직보다 "단계 간 계약 불일치"에서 자주 발생한다. 선언(완전 자동)과 실행(interactive fallback)을 반드시 같은 레벨에서 검증해야 한다.
