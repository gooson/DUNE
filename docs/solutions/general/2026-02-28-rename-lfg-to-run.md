---
tags: [skill, workflow, automation, pipeline, rename]
category: general
date: 2026-02-28
severity: minor
related_files: [.claude/skills/run/SKILL.md, CLAUDE.md, AGENTS.md]
related_solutions: [architecture/2026-02-16-agent-pipeline-integration]
---

# Solution: /lfg -> /run 리네이밍 + 완전 자동 파이프라인

## Problem

- `/lfg` 이름이 게이밍 슬랭("Let's Fucking Go")으로 직관적이지 않음
- 매 Phase 승인이 1인 개발 환경에서 불필요한 마찰
- P2 수동 확인이 자동화 흐름을 끊음

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `.claude/skills/run/SKILL.md` | 새 스킬 생성 | 직관적 이름 + 승인 제거 |
| `.claude/skills/lfg/SKILL.md` | 삭제 | 구 스킬 제거 |
| `CLAUDE.md` | 참조 2곳 업데이트 | 일관성 |
| `AGENTS.md` | 참조 2곳 업데이트 | 일관성 |
| docs 2개 | 참조 업데이트 | 일관성 |

### Key Changes in SKILL.md

1. 모든 Phase의 `Continue? [Y/n/back]` 프롬프트 제거
2. P2: 사용자 확인 -> 자동 수정
3. P3: TODO 기록 -> 자동 수정
4. P1 0건 확인 후 2회 재시도 게이트는 유지

## Prevention

- 스킬 이름은 동작을 직관적으로 표현하는 단어로 선택
- 1인 개발 환경에서는 승인 게이트 최소화 원칙

## Lessons Learned

1. 슬랭/약어 이름은 팀 확장 시 혼란 유발 가능
2. 승인 게이트는 팀 규모에 맞게 조절 (1인 -> 자동, 팀 -> 승인)
