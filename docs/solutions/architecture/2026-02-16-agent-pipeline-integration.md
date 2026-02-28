---
tags: [agent, pipeline, workflow, quality-gate, code-review, run, work-skill]
category: architecture
date: 2026-02-16
severity: important
related_files: [.claude/skills/work/SKILL.md, .claude/skills/run/SKILL.md, .claude/agents/]
related_solutions: []
---

# Solution: 전문 에이전트를 워크플로우 파이프라인에 통합

## Problem

### Symptoms

- `app-quality-gate`, `apple-ux-expert`, `swift-ui-expert`, `perf-optimizer`, `pr-reviewer` 에이전트가 존재하지만 워크플로우에서 자동 호출되지 않음
- `/work`, `/run` 실행 시 6관점 코드 리뷰만 수행되고 UI/성능/품질 전문 검증 누락
- PR 생성 전 최종 검증 단계 부재

### Root Cause

에이전트가 도구로 등록되어 있으나, `/work`와 `/run` 스킬의 파이프라인 정의에 포함되지 않아 수동 호출에만 의존.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `.claude/skills/work/SKILL.md` | Phase 3.2 전문 에이전트 검증 추가 | 변경 유형별 자동 에이전트 호출 |
| `.claude/skills/run/SKILL.md` | Phase 3.5 Quality Agents 추가 | 리뷰와 해결 사이 품질 에이전트 단계 |
| `.claude/skills/run/SKILL.md` | Phase 6에 pr-reviewer 추가 | PR 생성 전 최종 검증 |

### Key Code

```markdown
## /work Phase 3.2 — 변경 유형 기반 에이전트 선택

| 변경 유형 | 에이전트 | 실행 조건 |
|-----------|---------|-----------|
| UI/View 변경 | swift-ui-expert | SwiftUI View, Auto Layout |
| UI/View 변경 | apple-ux-expert | UX 흐름, HIG, 애니메이션 |
| 대량 데이터 | perf-optimizer | 1000+ 노드, 대용량 파싱 |
| 기능 완성 | app-quality-gate | 주요 기능 완료 시 종합 심사 |

## /run Phase 6 — PR 전 최종 검증

1. 최종 커밋 정리
2. pr-reviewer 에이전트 실행
3. PR 생성
```

## Prevention

### Checklist Addition

- [ ] 새 에이전트 추가 시 `/work` 또는 `/run` 파이프라인에 통합 여부 검토
- [ ] 에이전트 실행 조건을 명확히 정의 (모든 변경에 실행 X, 조건부 실행 O)

## Lessons Learned

1. **에이전트는 등록만으로는 부족하다**: 워크플로우 스킬에 명시적으로 호출 조건을 정의해야 실제로 활용됨
2. **조건부 실행이 핵심**: 모든 에이전트를 항상 실행하면 비용/시간 낭비. 변경 유형에 따른 선택적 실행이 효율적
3. **파이프라인 단계 번호 설계**: `/run`에서 Phase 3.5를 추가한 것처럼, 기존 번호 체계를 깨지 않으면서 단계를 삽입할 수 있는 유연성 필요
