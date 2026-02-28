---
tags: [skill, workflow, automation, pipeline]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: /lfg -> /run 리네이밍 + 승인 자동화

## Problem Statement

- `/lfg` 이름이 게이밍 슬랭("Let's Fucking Go")으로 직관적이지 않음
- 매 Phase마다 승인을 요구하여 파이프라인이 무거움
- P2 리뷰 항목을 수동 확인해야 해서 자동화 흐름이 끊김

## Target Users

- 프로젝트 유일 개발자 (본인)
- 파이프라인을 시작하면 결과(PR)만 확인하고 싶음

## Success Criteria

1. `/run` 커맨드가 Plan->Ship까지 승인 없이 자동 실행
2. P1/P2/P3 모두 자동 수정 (P1 0건 확인 후 Ship)
3. 기존 5개 파일의 `/lfg` 참조가 모두 `/run`으로 갱신

## Proposed Approach

### 1. 디렉토리 리네이밍

```
.claude/skills/lfg/SKILL.md -> .claude/skills/run/SKILL.md
```

### 2. SKILL.md 변경 사항

| 항목 | Before | After |
|------|--------|-------|
| name | `lfg` | `run` |
| Phase 1 (Plan) | 사용자 승인 필요 | 자동 진행 |
| Phase 2 (Work) | Quality Gate 후 진행 | 자동 진행 |
| Phase 3 (Review) | 결과 제시 후 대기 | 자동 진행 |
| Phase 4 (Resolve) | P1 자동, P2 수동, P3 TODO | P1+P2+P3 모두 자동 수정 |
| Phase 5 (Compound) | 수동 확인 | 자동 진행 |
| Phase 6 (Ship) | PR 생성 | 자동 PR 생성 |
| Pipeline Control | 매 Phase 후 `Continue? [Y/n/back]` | 제거, 완료 보고만 |

### 3. 참조 파일 업데이트

| 파일 | 변경 내용 |
|------|----------|
| `CLAUDE.md` | `/lfg` -> `/run` (2곳) |
| `AGENTS.md` | `lfg` -> `run` (2곳) |
| `docs/brainstorms/2026-02-28-skill-agent-system-audit.md` | `/lfg` -> `/run` (5곳) |
| `docs/solutions/architecture/2026-02-16-agent-pipeline-integration.md` | `/lfg` -> `/run` (8곳) |

## Constraints

- Error Recovery는 유지 (빌드 실패 시 자동 재시도 2회)
- P1 0건 확인은 유지 (Resolve 후 재리뷰)
- 파이프라인 완료 후 최종 보고는 유지

## Edge Cases

- 빌드 실패가 자동 복구 불가한 경우 -> 현행대로 사용자에게 보고 + 중단
- Review에서 P1이 재리뷰 후에도 남는 경우 -> 2회 시도 후 사용자에게 보고

## Scope

### MVP (이번 작업)
- [x] 디렉토리 + 파일 리네이밍
- [x] SKILL.md 승인 로직 제거 + P2/P3 자동 수정
- [x] 참조 파일 5개 업데이트

### Future
- `--fast` 모드: Plan -> Work -> Quick Review (3 agent) -> Ship
- `--dry-run` 모드: Ship 직전까지만 실행

## Next Steps

- `/plan` 으로 구현 계획 생성
