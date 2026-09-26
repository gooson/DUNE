# Codex Agent Map

`.claude/agents/*.md` 의 역할 intent를 Codex 런타임에 맞게 번역한 매핑이다. 원문 프롬프트는 그대로 유지하고, 이 문서는 **실행 policy delta** 만 기록한다.

공통 실행 규칙은 `.codex/skill-compat.md` 를 canonical source로 사용한다. 이 문서는 **agent별 차이점만** 기록한다.

## Model Routing

- 일반 구현/새 테스트/리뷰: `gpt-6-sol`, `medium`.
- 기존 패턴을 따르는 단순 테스트 추가/한정된 파일 조사: `gpt-6-luna`, `medium`.
- 테스트 실행/결과 집계: 먼저 셸 스크립트. 별도 언어 판단이 필요할 때만 `gpt-6-luna`, `low`.
- 아키텍처 결정, 복잡한 동시성/데이터 정합성, 원인이 불명확한 실패: `gpt-6-astra`, `high`.
- 아래 agent 배정은 기본값이다. 고위험 조건이면 처음부터 Astra, 같은 실패가 2회 반복되거나 근거가 부족하면 Luna → Sol → Astra로 상향한다. 단순 환경 장애는 모델 변경보다 환경 복구를 우선한다.
- 실제 지원 모델/추론 조합은 런타임에서 확인한다. 지정 모델이 없으면 조용히 Astra를 상속하지 말고 사용 가능한 대안과 이유를 기록한다.
- 앱 전역 모델이나 진행 중인 parent 모델은 이 파일로 바뀌지 않는다. 일반 작업은 사용자가 Sol로 시작할 수 있으며, Astra parent에서는 독립적인 하위 작업을 명시적으로 위임한다.

## Agents

### app-quality-gate

- Source: `.claude/agents/app-quality-gate.md`
- Role: holistic quality gate
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: review/quality 단계에서는 read-only, Resolve 단계에서만 small fix/test patch 허용
- Memory read: none
- Memory write: none

### apple-ux-expert

- Source: `.claude/agents/apple-ux-expert.md`
- Role: Apple UX/HIG review
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: review-only unless the user explicitly asks for UX implementation changes
- Memory read: none
- Memory write: none

### perf-optimizer

- Source: `.claude/agents/perf-optimizer.md`
- Role: performance diagnosis and optimization guidance
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: diagnosis is read-only; perf patching only in Work/Resolve
- Memory read: `.claude/agent-memory/reviewer-performance/MEMORY.md`
- Memory write: `.codex/agent-memory/perf-optimizer.md`
- Notes: Claude 문서의 repo 밖 persistent memory path는 Codex에서 shadow memory로 대체

### planner

- Source: `.claude/agents/planner.md`
- Role: implementation planning
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: no code edits
- Memory read: none
- Memory write: none

### pr-reviewer

- Source: `.claude/agents/pr-reviewer.md`
- Role: final diff review before PR/ship
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: read-only
- Memory read: none
- Memory write: none

### researcher

- Source: `.claude/agents/researcher.md`
- Role: codebase and docs research
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-luna`, `medium`
- Edit policy: no code edits
- Memory read: none
- Memory write: none

### reviewer-agent-native

- Source: `.claude/agents/reviewer-agent-native.md`
- Role: AI/agent prompt and tool-use review
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-agent-native/MEMORY.md`
- Memory write: none
- Notes: `.claude/`, `.codex/`, prompt, automation 관련 변경이 있을 때만 기본 후보

### reviewer-architecture

- Source: `.claude/agents/reviewer-architecture.md`
- Role: architecture review
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-architecture/MEMORY.md`
- Memory write: none

### reviewer-data-integrity

- Source: `.claude/agents/reviewer-data-integrity.md`
- Role: validation, transaction, consistency review
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-data-integrity/MEMORY.md`
- Memory write: none

### reviewer-performance

- Source: `.claude/agents/reviewer-performance.md`
- Role: performance review
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-performance/MEMORY.md`
- Memory write: none

### reviewer-security

- Source: `.claude/agents/reviewer-security.md`
- Role: security review
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-security/MEMORY.md`
- Memory write: none

### reviewer-simplicity

- Source: `.claude/agents/reviewer-simplicity.md`
- Role: simplicity and anti-overengineering review
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-simplicity/MEMORY.md`
- Memory write: none

### swift-ui-expert

- Source: `.claude/agents/swift-ui-expert.md`
- Role: SwiftUI/AppKit/UIKit implementation and debugging expert
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: review-only by default, implementation edits only when the user asks for UI changes or current Work/Resolve phase needs them
- Memory read: none
- Memory write: none

### ui-test-expert

- Source: `.claude/agents/ui-test-expert.md`
- Role: UI test strategy, review, and implementation
- Preferred execution: 공통 위임 정책 (`.codex/skill-compat.md`)
- Codex model/reasoning: `gpt-6-sol`, `medium`
- Edit policy: review-only in Review/Quality, test patching allowed in Work/Resolve
- Memory read: `.claude/skills/ui-testing/SKILL.md`
- Memory write: `.codex/agent-memory/ui-test-expert.md`
