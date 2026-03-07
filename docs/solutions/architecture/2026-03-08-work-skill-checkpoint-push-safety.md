---
tags: [agent, workflow, work-skill, git, checkpoint-commit, phase-push, dirty-worktree]
category: architecture
date: 2026-03-08
severity: critical
related_files:
  - .claude/skills/work/SKILL.md
related_solutions:
  - docs/solutions/architecture/2026-02-16-agent-pipeline-integration.md
---

# Solution: `/work` 스킬의 체크포인트 커밋과 Phase Push 안전성 강화

## Problem

### Symptoms

- `/work` 스킬이 작은 단위 커밋을 권장하지만 `git add -A` 예시 때문에 관련 없는 dirty worktree 변경까지 함께 커밋될 수 있었음
- Phase 완료 시 자동 push 규칙에 브랜치 안전장치가 없어, `main` 에서 `/work` 를 시작하면 중간 구현 커밋이 그대로 원격 `main` 으로 push될 수 있었음
- `git stash` fallback을 허용하면서도 Phase 완료 기준은 commit + push 기준으로만 설명해, 최신 작업이 로컬 stash에만 남는 상태를 허용하고 있었음

### Root Cause

작업 손실 방지를 위해 "자주 커밋하고 Phase 끝에 push한다"는 방향은 추가했지만, Git 자동화에 필요한 세 가지 안전조건이 빠져 있었다.

1. **staging scope safety**: 전체 worktree가 아니라 현재 작업 단위 파일만 커밋해야 함
2. **branch safety**: 자동 commit/push는 `main` 이 아닌 작업 브랜치에서만 허용해야 함
3. **checkpoint integrity**: stash는 임시 보존일 뿐이며, Phase 완료 전 commit으로 승격되어야 함

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `.claude/skills/work/SKILL.md` | Setup에 baseline dirty 파일 기록 추가 | 기존 dirty 변경을 자동 커밋 범위에서 제외 |
| `.claude/skills/work/SKILL.md` | Setup에 `main` 브랜치 안전장치 추가 | 중간 구현 커밋의 `main` push 방지 |
| `.claude/skills/work/SKILL.md` | Implement에 현재 작업 단위 파일 목록 확정 + `git add -- {current-unit-files...}` 규칙 추가 | 관련 없는 변경이 체크포인트 커밋에 섞이지 않게 제한 |
| `.claude/skills/work/SKILL.md` | `git add -A` 금지와 baseline 제외 규칙 추가 | dirty worktree 환경에서 안전한 자동 커밋 보장 |
| `.claude/skills/work/SKILL.md` | `work-checkpoint-*` stash를 Phase 완료 조건에서 제외 | 로컬 stash만 남고 remote backup이 없는 상태 차단 |
| `.claude/skills/work/SKILL.md` | Phase 경계 push 전에 `main` 여부와 남은 stash 여부 검사 추가 | 자동 push의 전제 조건을 명확히 강제 |

### Key Code

```markdown
## Setup
- 시작 시점에 이미 dirty인 파일 목록을 baseline으로 기록합니다
- 현재 브랜치가 `main` 이면 Phase 2 전에 반드시 작업 브랜치로 전환합니다
- `main` 에서는 구현 커밋이나 자동 push를 진행하지 않습니다

## Implement
- 각 작은 단위마다 이번 단위에서 수정할 파일 목록을 먼저 확정합니다
- `git add -- {current-unit-files...} && git commit -m "<type>(<scope>): <summary>"`
- `git add -A` 로 전체 worktree를 스테이징하지 않습니다
- baseline 파일이나 관련 없는 기존 변경은 커밋에 포함하지 않습니다

## Phase 경계 Push 정책
- 현재 브랜치가 `main` 이면 push하지 않고 먼저 작업 브랜치로 전환합니다
- `work-checkpoint-*` stash가 남아 있으면 Phase 완료로 간주하지 않습니다
```

## Prevention

### Checklist Addition

- [ ] Git 자동화가 포함된 skill은 `main` 브랜치에서 자동 commit/push를 금지하는가?
- [ ] 자동 커밋 예시는 전체 worktree가 아니라 현재 작업 단위 파일만 대상으로 하는가?
- [ ] dirty worktree baseline을 기록하고 기존 변경을 자동 커밋 범위에서 제외하는가?
- [ ] stash fallback이 있다면 Phase 완료 전에 commit으로 승격하도록 강제하는가?
- [ ] remote backup을 약속한다면 stash-only 상태를 완료로 처리하지 않는가?

### Rule Addition (if applicable)

현재는 `.claude/skills/work/SKILL.md` 자체에 안전장치를 내장하는 것으로 충분하다. 같은 패턴이 다른 스킬에도 반복되면 `.claude/rules/` 에 `git-automation-safety.md` 같은 공통 규칙으로 승격하는 것을 검토한다.

## Lessons Learned

1. **자주 커밋하는 것만으로는 안전하지 않다**: 어떤 파일을 staging하는지와 어떤 브랜치에서 push하는지가 함께 정의되어야 한다.
2. **remote backup 약속에는 완료 조건이 필요하다**: stash처럼 로컬에만 존재하는 임시 상태를 Phase 완료로 인정하면 정책이 스스로 깨진다.
3. **dirty worktree는 예외가 아니라 기본 상황이다**: 에이전트 스킬은 항상 기존 변경이 섞여 있을 수 있다고 가정하고 범위를 좁혀서 동작해야 한다.
