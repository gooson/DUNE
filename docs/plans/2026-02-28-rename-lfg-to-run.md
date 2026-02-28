---
tags: [skill, workflow, automation, pipeline, rename]
date: 2026-02-28
category: plan
status: approved
---

# Plan: /lfg -> /run 리네이밍 + 승인 자동화

## Summary

`/lfg` 스킬을 `/run`으로 리네이밍하고, 모든 Phase의 승인 게이트를 제거하여 완전 자동 파이프라인으로 전환.

## Affected Files

| File | Change | Type |
|------|--------|------|
| `.claude/skills/run/SKILL.md` | 새 파일 생성 (lfg 내용 기반 재작성) | Create |
| `.claude/skills/lfg/SKILL.md` | 삭제 | Delete |
| `CLAUDE.md` | `/lfg` -> `/run` (2곳) | Edit |
| `AGENTS.md` | `lfg` -> `run` (2곳) | Edit |
| `docs/brainstorms/2026-02-28-skill-agent-system-audit.md` | `/lfg` -> `/run` (5곳) | Edit |
| `docs/solutions/architecture/2026-02-16-agent-pipeline-integration.md` | `/lfg` -> `/run` (8곳) | Edit |

## Implementation Steps

1. `.claude/skills/run/SKILL.md` 생성 (승인 제거 + P1/P2/P3 자동 수정)
2. `.claude/skills/lfg/SKILL.md` 삭제
3. `CLAUDE.md` 참조 업데이트
4. `AGENTS.md` 참조 업데이트
5. docs 2개 파일 참조 업데이트
6. 빌드 영향 없음 (Swift 코드 변경 없음)

## Key Behavior Changes

- Phase 간 `Continue? [Y/n/back]` 프롬프트 제거
- P2: 사용자 확인 -> 자동 수정
- P3: TODO 기록 -> 자동 수정
- Pipeline Control 섹션 -> 자동 진행 + 완료 보고
