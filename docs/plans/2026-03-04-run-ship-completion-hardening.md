---
topic: run-ship-completion-hardening
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-02-16-agent-pipeline-integration.md
  - docs/solutions/general/2026-02-28-rename-lfg-to-run.md
related_brainstorms: []
---

# Implementation Plan: Run Skill Ship Completion Hardening

## Context

`/run`은 "승인 없이 끝까지 자동 진행"을 목표로 하지만, 기존 `/ship`의 사용자 선택 분기(미커밋 변경 처리)와 충돌하여 파이프라인이 중간에 멈출 수 있었다. `run -> ship` 경계를 비대화형으로 정렬해 완주 가능성을 높인다.

## Requirements

### Functional

- `/run`에서 `ship` 진입 전 clean worktree/remote/auth/diff gate를 강제한다.
- `/ship` 기본 동작을 비대화형으로 전환한다.
- 미커밋 변경이 있어도 자동 처리 경로(커밋 -> stash)를 제공한다.
- PR 미생성/merge 대기 상황에서 재시도 또는 안전 종료 경로를 제공한다.

### Non-functional

- 기존 merge 정책(`--merge` 기본)을 유지한다.
- build pipeline 규칙(`scripts/lib/regen-project.sh`)을 유지한다.
- 문서/스킬 정의 간 모순(자동 진행 vs 사용자 선택)을 제거한다.

## Approach

`run`에 Phase 5.5 pre-ship gate를 추가하고, `ship`의 interactive 분기를 default non-interactive 정책으로 교체한다. 두 스킬을 동시에 업데이트해 경계면 계약(contract)을 맞춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `/run`만 수정 | 변경 범위가 작음 | `/ship` 문서와 충돌 지속 | 기각 |
| `/ship`만 수정 | ship 단독 실행 안정화 | `/run` pre-ship gate 부재 | 기각 |
| `run + ship` 동시 정렬 | 계약 일관성, 완주율 개선 | 문서 2개 동시 수정 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `.claude/skills/run/SKILL.md` | modify | Phase 5.5 pre-ship gate 추가, Phase 6 비대화형 ship 호출 명시 |
| `.claude/skills/ship/SKILL.md` | modify | interactive 분기 제거, 자동 커밋/stash/재시도 정책 추가 |
| `docs/solutions/general/2026-03-04-run-ship-completion-hardening.md` | add | 문제/해결/예방 문서화 |
| `CLAUDE.md` | modify | Correction Log 프로세스 항목 추가 |

## Implementation Steps

### Step 1: run/ship 계약 충돌 지점 식별

- **Files**: `.claude/skills/run/SKILL.md`, `.claude/skills/ship/SKILL.md`
- **Changes**: 자동 진행 선언과 사용자 선택 요구 구간 매핑
- **Verification**: 충돌 시나리오(미커밋 변경, PR/merge 대기) 재현 가능성 확인

### Step 2: run pre-ship gate + ship 비대화형 정책 반영

- **Files**: `.claude/skills/run/SKILL.md`, `.claude/skills/ship/SKILL.md`
- **Changes**: clean worktree/auth/diff gate, auto commit/stash fallback, pending checks 재시도 추가
- **Verification**: 두 문서 간 상충 문구 제거, 단계 흐름 연결성 확인

### Step 3: Compound/Correction 문서화

- **Files**: `docs/solutions/general/...`, `CLAUDE.md`
- **Changes**: 해결 패턴, 체크리스트, 프로세스 교정 로그 기록
- **Verification**: 문서 frontmatter/날짜/카테고리 규격 확인

## Edge Cases

| Case | Handling |
|------|----------|
| detached HEAD에서 `/run` 실행 | pre-ship 단계에서 feature branch 생성 가드 적용 |
| 변경이 없는데 ship 호출 | `main...HEAD` diff 0이면 ship 생략 후 종료 보고 |
| auto commit 실패(훅/충돌) | stash fallback 후 진행, 둘 다 실패 시 중단 |
| CI checks pending | 대기 후 재시도(최대 2회) |

## Testing Strategy

- Unit tests: 문서/스킬 변경 작업이라 해당 없음
- Integration tests: 실제 `gh` 네트워크/권한 환경에서 `/run` dry-run 권장
- Manual verification: `git diff`로 run/ship 흐름 충돌 제거 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 실제 gh 권한/토큰 만료 | medium | high | pre-ship `gh auth status` 확인 및 실패시 즉시 보고 |
| auto-commit 메시지 과다 생성 | low | medium | pre-ship에서 최소 1회만 수행, 실패 시 stash로 전환 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: run/ship 양쪽에 동일한 비대화형 계약을 반영해 중단 경로를 구조적으로 제거했다.
