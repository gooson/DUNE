---
name: agent-architecture
description: "이 프로젝트의 에이전트 시스템 아키텍처. 리뷰 에이전트 6종, 품질 에이전트 4종, PR 에이전트의 역할과 실행 규칙. 에이전트 프롬프트를 수정하거나 새 에이전트를 추가할 때, 또는 /review나 /run에서 에이전트 실행 문제가 발생할 때 이 스킬을 참조합니다."
---

# Agent Architecture — DUNE Project

## Agent Inventory

이 프로젝트는 14개의 서브에이전트를 사용합니다. 모두 `.claude/agents/` 에 정의되어 있습니다.

### Review Agents (6종)

`/review` 스킬이 병렬로 실행하는 코드 리뷰 전문가입니다.

| Agent | File | 관점 | 실행 조건 |
|-------|------|------|----------|
| Security Sentinel | `reviewer-security.md` | OWASP, 인증, 입력 검증, 비밀 노출 | 항상 |
| Performance Oracle | `reviewer-performance.md` | N+1, 캐싱, 메모리, 알고리즘 | 항상 |
| Architecture Strategist | `reviewer-architecture.md` | SOLID, 패턴, 결합도/응집도 | 항상 |
| Data Integrity Guardian | `reviewer-data-integrity.md` | 유효성, 트랜잭션, 레이스 컨디션 | 항상 |
| Code Simplicity Reviewer | `reviewer-simplicity.md` | 과잉 설계, 불필요 추상화, dead code | 항상 |
| Agent-Native Reviewer | `reviewer-agent-native.md` | 프롬프트, 컨텍스트, 도구 사용 | `.claude/` 변경 시에만 |

### Quality Agents (4종)

`/work` Phase 3과 `/run` Phase 3.5에서 변경 내용에 따라 선택적으로 실행합니다.

| Agent | File | 역할 | 실행 조건 |
|-------|------|------|----------|
| Swift UI Expert | `swift-ui-expert.md` | 레이아웃, Auto Layout, SwiftUI 구현 | UI/View 코드 변경 |
| Apple UX Expert | `apple-ux-expert.md` | HIG 준수, UX 흐름, 애니메이션 | UI/View 코드 변경 |
| Performance Optimizer | `perf-optimizer.md` | 스크롤, 메모리, 파싱 최적화 | 대량 데이터 처리 구현 |
| App Quality Gate | `app-quality-gate.md` | 코드+테스트+HIG+아키텍처 종합 | 주요 기능 완성 |

### Utility Agents (4종)

| Agent | File | 역할 | 호출 시점 |
|-------|------|------|----------|
| PR Reviewer | `pr-reviewer.md` | git diff + rules 검증 + 크래시 위험 검출 | `/ship`, `/run` Phase 6 |
| Planner | `planner.md` | 구현 전략 설계 | `/plan` 리서치 |
| Researcher | `researcher.md` | 코드베이스/문서 조사 | 탐색적 리서치 |
| UI Test Expert | `ui-test-expert.md` | UI 테스트 시나리오 생성/검증 | UI 변경 후 |

## Execution Rules

### Review Agents 실행 규칙

1. **병렬 실행 필수**: 6개 에이전트를 하나의 메시지에서 동시 launch
2. **model: sonnet**: 각 리뷰 에이전트는 `claude-sonnet-4-6`으로 실행
3. **max_turns: 6**: 토큰 초과 방지를 위해 턴 수 제한
4. **diff 크기 제한**: 2000줄 이상이면 에이전트 대신 주 에이전트가 직접 리뷰
5. **Agent-Native 스킵**: `.claude/` 하위 파일 변경이 없으면 항상 스킵

### Quality Agents 실행 규칙

1. **조건부 실행**: `git diff --name-only`로 변경 파일 분류 후 해당 에이전트만 launch
2. **병렬 실행 권장**: 가능하면 동시 실행
3. **스킵 시 사유 기록**: 에이전트를 실행하지 않은 경우 왜 스킵했는지 명시

### PR Reviewer 실행 규칙

1. **ship 직전 실행**: PR 생성 전에 `.claude/rules/` 기반 코딩 룰 준수 검증
2. **단독 실행**: 다른 에이전트와 병렬이 아닌 독립 단계

## Agent Prompt 작성 원칙

새 에이전트를 추가하거나 기존 에이전트를 수정할 때:

1. **단일 책임**: 하나의 에이전트는 하나의 명확한 관점만 담당
2. **프로젝트 컨텍스트 제공**: `.claude/rules/` 의 관련 규칙을 에이전트 프롬프트에 포함하거나 참조
3. **출력 형식 통일**: P1/P2/P3 우선순위 + File:Line + Issue + Suggestion 구조
4. **간결한 지시**: "git diff 1회 실행 후 findings만 출력"처럼 불필요한 탐색 최소화
5. **프로젝트 규칙 연동**: performance-patterns, swiftui-patterns 등 rules와 일관된 기준 적용

## Agent 간 관계

```
/review ──→ [Review Agents ×5-6] ──→ P1/P2/P3 통합
                                         │
/run ───→ /review + [Quality Agents] ──→ /resolve ──→ /ship
                                                        │
                                              [PR Reviewer] ──→ PR 생성
```

- Review Agents의 findings는 `/triage`로 분류하거나 `/run`의 Resolve Phase에서 자동 수정
- Quality Agents의 findings는 Review findings에 병합
- PR Reviewer는 최종 ship 게이트로 독립 실행

## Adding a New Agent

### Step-by-step

1. `.claude/agents/` 에 `{agent-name}.md` 파일 생성
2. 아래 템플릿을 사용하여 프롬프트 작성
3. `agent-architecture` 스킬의 Agent Inventory 테이블에 추가
4. 호출하는 스킬(review, work, run 등)에 에이전트 실행 조건 추가
5. 테스트: 실제 diff에 대해 에이전트를 launch하여 출력 품질 확인

### Agent Prompt Template

```markdown
---
name: {agent-name}
description: "{한 줄 설명}"
tools: Read, Grep, Glob, Bash(git diff *)
model: sonnet
memory: project
---

You are a {Role Name} reviewing code for {specific focus area}.

## Focus Areas

1. **{Area 1}**: {구체적 검사 항목}
2. **{Area 2}**: {구체적 검사 항목}
3. **{Area 3}**: {구체적 검사 항목}

## Review Process

1. Run `git diff HEAD` (or `git diff main...HEAD` if empty) — **한 번만 실행**
2. Focus ONLY on modified/added files
3. Analyze each change for {focus area} implications
4. Classify findings by priority (P1/P2/P3)

## CRITICAL: Output Size Control

- Tool call을 최소화합니다. `git diff` 1회 + 필요 시 `Read` 몇 회만 실행
- 불필요한 `Grep`/`Glob` 탐색을 하지 않습니다
- **최종 응답은 findings만 포함** — 분석 과정, 읽은 파일 내용, 중간 사고를 포함하지 않습니다

## Project-Specific Rules

- `.claude/rules/{relevant-rule}.md` 의 규칙을 기준으로 검사
- {프로젝트 특화 규칙 나열}

## Output Format

P1/P2/P3로 분류하여 각 finding에 포함:
- **File**: path:line
- **Issue**: 무엇이 문제인지
- **Suggestion**: 어떻게 수정할지
```

### Key Principles

- **model: sonnet** — 비용 효율성. 리뷰 에이전트는 sonnet으로 충분
- **Output Size Control 필수** — 이 섹션이 없으면 에이전트가 diff 전체를 출력에 포함하여 truncation 발생
- **단일 관점** — 하나의 에이전트가 여러 관점을 커버하면 각 관점의 깊이가 얕아짐
- **memory: project** — 에이전트가 프로젝트별 패턴을 학습하여 리뷰 정확도 향상

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| 에이전트 output truncation | diff가 너무 큼 | diff < 2000줄 확인, 초과 시 직접 리뷰 |
| 에이전트가 findings 없이 종료 | max_turns 부족 또는 diff 미전달 | diff를 /tmp에 저장 후 경로 전달 |
| Agent-Native가 항상 실행됨 | 스킵 조건 미적용 | `.claude/` 변경 여부를 diff --name-only로 먼저 확인 |
| 리뷰 에이전트 간 중복 findings | 관점 경계 불명확 | 각 에이전트의 관점을 명확히 구분 (보안≠성능≠아키텍처) |
