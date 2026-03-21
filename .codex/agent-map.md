# Codex Agent Map

`.claude/agents/*.md` 의 역할 intent를 Codex 런타임에 맞게 번역한 매핑이다. 원문 프롬프트는 그대로 유지하고, 이 문서는 **실행 policy delta** 만 기록한다.

공통 실행 규칙은 `.codex/skill-compat.md` 를 canonical source로 사용한다. 이 문서는 **agent별 차이점만** 기록한다.

## Agents

### app-quality-gate

- Source: `.claude/agents/app-quality-gate.md`
- Role: holistic quality gate
- Preferred execution: inline first, optional `worker` spawn when explicit delegation is allowed
- Codex model/reasoning: `gpt-5.4`, `high`
- Edit policy: review/quality 단계에서는 read-only, Resolve 단계에서만 small fix/test patch 허용
- Memory read: none
- Memory write: none

### apple-ux-expert

- Source: `.claude/agents/apple-ux-expert.md`
- Role: Apple UX/HIG review
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4`, `high`
- Edit policy: review-only unless the user explicitly asks for UX implementation changes
- Memory read: none
- Memory write: none

### perf-optimizer

- Source: `.claude/agents/perf-optimizer.md`
- Role: performance diagnosis and optimization guidance
- Preferred execution: inline first, optional `explorer` for diagnosis or `worker` for bounded perf patch
- Codex model/reasoning: `gpt-5.4`, `high`
- Edit policy: diagnosis is read-only; perf patching only in Work/Resolve
- Memory read: `.claude/agent-memory/reviewer-performance/MEMORY.md`
- Memory write: `.codex/agent-memory/perf-optimizer.md`
- Notes: Claude 문서의 repo 밖 persistent memory path는 Codex에서 shadow memory로 대체

### planner

- Source: `.claude/agents/planner.md`
- Role: implementation planning
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: no code edits
- Memory read: none
- Memory write: none

### pr-reviewer

- Source: `.claude/agents/pr-reviewer.md`
- Role: final diff review before PR/ship
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: read-only
- Memory read: none
- Memory write: none

### researcher

- Source: `.claude/agents/researcher.md`
- Role: codebase and docs research
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: no code edits
- Memory read: none
- Memory write: none

### reviewer-agent-native

- Source: `.claude/agents/reviewer-agent-native.md`
- Role: AI/agent prompt and tool-use review
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-agent-native/MEMORY.md`
- Memory write: none
- Notes: `.claude/`, `.codex/`, prompt, automation 관련 변경이 있을 때만 기본 후보

### reviewer-architecture

- Source: `.claude/agents/reviewer-architecture.md`
- Role: architecture review
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-architecture/MEMORY.md`
- Memory write: none

### reviewer-data-integrity

- Source: `.claude/agents/reviewer-data-integrity.md`
- Role: validation, transaction, consistency review
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-data-integrity/MEMORY.md`
- Memory write: none

### reviewer-performance

- Source: `.claude/agents/reviewer-performance.md`
- Role: performance review
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-performance/MEMORY.md`
- Memory write: none

### reviewer-security

- Source: `.claude/agents/reviewer-security.md`
- Role: security review
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-security/MEMORY.md`
- Memory write: none

### reviewer-simplicity

- Source: `.claude/agents/reviewer-simplicity.md`
- Role: simplicity and anti-overengineering review
- Preferred execution: inline first, optional `explorer` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: read-only
- Memory read: `.claude/agent-memory/reviewer-simplicity/MEMORY.md`
- Memory write: none

### swift-ui-expert

- Source: `.claude/agents/swift-ui-expert.md`
- Role: SwiftUI/AppKit/UIKit implementation and debugging expert
- Preferred execution: inline first, optional `explorer` or bounded `worker`
- Codex model/reasoning: `gpt-5.4`, `high`
- Edit policy: review-only by default, implementation edits only when the user asks for UI changes or current Work/Resolve phase needs them
- Memory read: none
- Memory write: none

### ui-test-expert

- Source: `.claude/agents/ui-test-expert.md`
- Role: UI test strategy, review, and implementation
- Preferred execution: inline first, optional `worker` spawn
- Codex model/reasoning: `gpt-5.4-mini`, `medium`
- Edit policy: review-only in Review/Quality, test patching allowed in Work/Resolve
- Memory read: `.claude/skills/ui-testing/SKILL.md`
- Memory write: `.codex/agent-memory/ui-test-expert.md`
