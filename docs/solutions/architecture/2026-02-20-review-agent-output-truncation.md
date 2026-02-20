---
tags: [review-skill, task-agent, output-truncation, subagent, token-limit]
category: architecture
date: 2026-02-20
severity: important
related_files:
  - .claude/skills/review/SKILL.md
  - .claude/agents/reviewer-security.md
  - .claude/agents/reviewer-performance.md
  - .claude/agents/reviewer-architecture.md
  - .claude/agents/reviewer-data-integrity.md
  - .claude/agents/reviewer-simplicity.md
  - .claude/agents/reviewer-agent-native.md
related_solutions: []
---

# Solution: Review Agent Output Truncation

## Problem

### Symptoms

- `/review` skill 실행 시 "Prompt is too long" 에러 발생
- 서브에이전트 output 파일에 JSON tool call 로그가 전체 포함되어 truncation
- 에이전트가 `git diff`를 읽으려 할 때 "File content (41852 tokens) exceeds maximum allowed tokens (25000)" 에러

### Root Cause

1. **Output 파일 크기**: Task tool의 output 파일에는 에이전트의 전체 대화 로그(tool calls, API responses, hook events)가 포함됨. 에이전트가 많은 tool을 호출할수록 output이 커져서 truncation 발생
2. **Diff 크기 제한**: 서브에이전트는 파일 읽기에 25000 토큰 제한이 있음. 대규모 diff(3000줄+)는 이 한도 초과
3. **불필요한 탐색**: 리뷰 에이전트가 `Grep`/`Glob` 등으로 불필요한 탐색을 수행하여 output 증가

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `.claude/agents/reviewer-*.md` (6개) | Output Size Control 섹션 추가 | tool call 최소화, findings만 출력 지시 |
| `.claude/skills/review/SKILL.md` | `max_turns: 6`, `model: sonnet`, diff 크기 기반 fallback 추가 | 에이전트 턴 수 제한, 대규모 diff 시 직접 리뷰로 전환 |

### Key Code

각 리뷰어 에이전트에 추가된 Output Size Control:

```markdown
## CRITICAL: Output Size Control

- Tool call을 최소화합니다. `git diff` 1회 + 필요 시 `Read` 몇 회만 실행
- 불필요한 `Grep`/`Glob` 탐색을 하지 않습니다
- **최종 응답은 findings만 포함** — 분석 과정, 읽은 파일 내용, 중간 사고를 포함하지 않습니다
- 발견사항이 없으면 한 줄로 "No {type} issues found." 만 출력합니다
```

SKILL.md의 diff 크기 기반 fallback:

```markdown
**diff가 2000줄 이상이면 에이전트 대신 직접 리뷰**:
- 에이전트에 git diff를 전달하면 토큰 한도(25000)를 초과하여 실패합니다
- 대신 주 에이전트가 `git diff main...HEAD -- {path}` 로 폴더별로 나눠 읽고 직접 5관점 리뷰합니다
```

## Prevention

### Checklist Addition

- [ ] 리뷰 에이전트 수정 시 Output Size Control 섹션 유지 확인
- [ ] 새 리뷰 에이전트 추가 시 동일 Output Size Control 패턴 적용

### Rule Addition

없음 — SKILL.md 자체가 규칙 역할을 수행

## Lessons Learned

1. **Task tool output = 전체 대화 로그**: 서브에이전트의 output 파일은 최종 답변이 아니라 전체 tool call 기록을 포함함. 에이전트가 tool을 많이 호출할수록 output이 커짐
2. **에이전트에게 "하지 말 것"을 명시해야 함**: 기본적으로 에이전트는 최대한 많이 탐색하려 함. "tool call 최소화", "findings만 출력" 등을 명시적으로 지시해야 output 크기 제어 가능
3. **대규모 diff는 에이전트 우회**: 25000 토큰 제한은 하드 리밋. diff가 이를 초과하면 에이전트 대신 주 에이전트가 직접 리뷰하는 fallback이 필수
