# Codex <-> Claude Settings Parity

이 워크스페이스에서 Codex는 `.claude` 하위 설정을 **누락 없이** 그대로 사용합니다.

## Source Of Truth

- Primary: `/Users/shanks/work/Health/.claude/`
- Note: `/Users/shanks/work/Health/.claude/worktrees/*/.claude/` 는 동일 설정의 복제본입니다.

## Skills

A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used.

### Available skills

- skill-creator: Guide for creating effective skills. Use when users ask to create/update a skill that extends Codex capabilities. (file: /Users/shanks/.codex/skills/.system/skill-creator/SKILL.md)
- skill-installer: Install Codex skills from curated list or GitHub repo path. Use when users ask to list/install skills. (file: /Users/shanks/.codex/skills/.system/skill-installer/SKILL.md)

- agent-architecture: 에이전트 시스템 아키텍처 패턴. 에이전트 설계/프롬프트/컨텍스트 관리 시 사용. (file: /Users/shanks/work/Health/.claude/skills/agent-architecture/SKILL.md)
- brainstorm: 아이디어나 요구사항이 모호할 때 구조화된 질문으로 명확화. (file: /Users/shanks/work/Health/.claude/skills/brainstorm/SKILL.md)
- changelog: 최근 변경사항 기반 릴리스 노트 생성. (file: /Users/shanks/work/Health/.claude/skills/changelog/SKILL.md)
- code-style: 코드 스타일/컨벤션 참조. (file: /Users/shanks/work/Health/.claude/skills/code-style/SKILL.md)
- compound: 해결된 문제를 docs/solutions 에 문서화. (file: /Users/shanks/work/Health/.claude/skills/compound/SKILL.md)
- copy-voice: 문서/UI 문구 톤앤매너 가이드. (file: /Users/shanks/work/Health/.claude/skills/copy-voice/SKILL.md)
- debug: 재현->격리->가설->검증->수정->확인->문서화 디버깅 루프. (file: /Users/shanks/work/Health/.claude/skills/debug/SKILL.md)
- design-system: UI/UX 디자인 시스템 가이드. (file: /Users/shanks/work/Health/.claude/skills/design-system/SKILL.md)
- lfg: Plan->Work->Review->Resolve->Compound->Ship 전체 파이프라인 실행. (file: /Users/shanks/work/Health/.claude/skills/lfg/SKILL.md)
- onboard: 프로젝트 온보딩 실행. (file: /Users/shanks/work/Health/.claude/skills/onboard/SKILL.md)
- plan: 구현 계획 생성. (file: /Users/shanks/work/Health/.claude/skills/plan/SKILL.md)
- retrospective: 세션 회고 및 교정사항 반영. (file: /Users/shanks/work/Health/.claude/skills/retrospective/SKILL.md)
- review: 6개 관점(Security/Performance/Architecture/Data/Simplicity/Agent-Native) 리뷰. (file: /Users/shanks/work/Health/.claude/skills/review/SKILL.md)
- ship: PR 생성 -> 머지 -> 브랜치 정리. (file: /Users/shanks/work/Health/.claude/skills/ship/SKILL.md)
- testing-patterns: 테스트 작성 패턴/커버리지 규칙. (file: /Users/shanks/work/Health/.claude/skills/testing-patterns/SKILL.md)
- triage: 리뷰 결과를 승인/스킵/즉시수정으로 분류. (file: /Users/shanks/work/Health/.claude/skills/triage/SKILL.md)
- ui-testing: UI 테스트 패턴 및 iPad/iPhone 호환성 가이드. (file: /Users/shanks/work/Health/.claude/skills/ui-testing/SKILL.md)
- work: Setup->Implement->Quality Check->Ship 4단계 구현 실행. (file: /Users/shanks/work/Health/.claude/skills/work/SKILL.md)
- xcode-project: xcodegen 기반 빌드/테스트/프로젝트 관리. (file: /Users/shanks/work/Health/.claude/skills/xcode-project/SKILL.md)

### How to use skills

- Discovery: 위 목록이 이 세션에서 사용 가능한 skill 전체입니다.
- Trigger rules: 사용자가 skill 이름을 명시(`$skill`, `/skill`, plain text)하거나 요청이 skill 설명과 명확히 일치하면 해당 skill을 반드시 사용합니다.
- Multiple skills: 여러 skill이 맞으면 최소 집합으로 적용하고 적용 순서를 한 줄로 먼저 알립니다.
- Read scope: `SKILL.md`는 필요한 만큼만 읽고, 참조된 파일도 필요한 파일만 추가로 읽습니다.
- Relative paths: skill 내부 상대 경로는 해당 skill 디렉토리 기준으로 해석합니다.
- Scripts/templates: `scripts/`, `templates/`, `assets/`가 있으면 재사용을 우선합니다.
- Missing skill: 경로나 파일이 없으면 짧게 알리고 최선의 대안으로 계속 진행합니다.
- Context hygiene: 대량 파일 전체 로딩을 피하고 요약 중심으로 컨텍스트를 유지합니다.

### Skill templates

- plan template: /Users/shanks/work/Health/.claude/skills/plan/templates/plan-template.md
- review template: /Users/shanks/work/Health/.claude/skills/review/templates/review-report.md
- compound template: /Users/shanks/work/Health/.claude/skills/compound/templates/solution-template.md

## Agent Profiles (Claude parity)

아래 프롬프트 파일은 Claude sub-agent 설정과 동일한 역할을 수행합니다.

- app-quality-gate: /Users/shanks/work/Health/.claude/agents/app-quality-gate.md
- apple-ux-expert: /Users/shanks/work/Health/.claude/agents/apple-ux-expert.md
- perf-optimizer: /Users/shanks/work/Health/.claude/agents/perf-optimizer.md
- planner: /Users/shanks/work/Health/.claude/agents/planner.md
- pr-reviewer: /Users/shanks/work/Health/.claude/agents/pr-reviewer.md
- researcher: /Users/shanks/work/Health/.claude/agents/researcher.md
- reviewer-agent-native: /Users/shanks/work/Health/.claude/agents/reviewer-agent-native.md
- reviewer-architecture: /Users/shanks/work/Health/.claude/agents/reviewer-architecture.md
- reviewer-data-integrity: /Users/shanks/work/Health/.claude/agents/reviewer-data-integrity.md
- reviewer-performance: /Users/shanks/work/Health/.claude/agents/reviewer-performance.md
- reviewer-security: /Users/shanks/work/Health/.claude/agents/reviewer-security.md
- reviewer-simplicity: /Users/shanks/work/Health/.claude/agents/reviewer-simplicity.md
- swift-ui-expert: /Users/shanks/work/Health/.claude/agents/swift-ui-expert.md
- ui-test-expert: /Users/shanks/work/Health/.claude/agents/ui-test-expert.md

## Agent Memory (Claude parity)

- reviewer-agent-native: /Users/shanks/work/Health/.claude/agent-memory/reviewer-agent-native/MEMORY.md
- reviewer-architecture: /Users/shanks/work/Health/.claude/agent-memory/reviewer-architecture/MEMORY.md
- reviewer-data-integrity: /Users/shanks/work/Health/.claude/agent-memory/reviewer-data-integrity/MEMORY.md
- reviewer-performance: /Users/shanks/work/Health/.claude/agent-memory/reviewer-performance/MEMORY.md
- reviewer-security: /Users/shanks/work/Health/.claude/agent-memory/reviewer-security/MEMORY.md
- reviewer-simplicity: /Users/shanks/work/Health/.claude/agent-memory/reviewer-simplicity/MEMORY.md

## Always-On Project Docs

- Project handbook: `/Users/shanks/work/Health/CLAUDE.md` (Correction Log 포함)
- Rules directory: `/Users/shanks/work/Health/.claude/rules/`

### Mandatory rules

- /Users/shanks/work/Health/.claude/rules/compound-workflow.md
- /Users/shanks/work/Health/.claude/rules/documentation-standards.md
- /Users/shanks/work/Health/.claude/rules/healthkit-patterns.md
- /Users/shanks/work/Health/.claude/rules/input-validation.md
- /Users/shanks/work/Health/.claude/rules/swift-layer-boundaries.md
- /Users/shanks/work/Health/.claude/rules/swiftdata-cloudkit.md
- /Users/shanks/work/Health/.claude/rules/testing-required.md
- /Users/shanks/work/Health/.claude/rules/todo-conventions.md
- /Users/shanks/work/Health/.claude/rules/watch-navigation.md

## Trigger Rules (Parity)

- 사용자 입력에 `/brainstorm`, `/plan`, `/work`, `/review`, `/triage`, `/compound`, `/ship`, `/lfg`, `/debug`, `/onboard`, `/retrospective`, `/changelog` 가 포함되면 동일 이름 skill을 우선 적용합니다.
- 사용자가 특정 agent 이름(예: `reviewer-security`, `swift-ui-expert`)을 직접 언급하면 해당 `.claude/agents/{name}.md`를 우선 적용합니다.
- "리뷰해줘/품질 검토/출시 전 점검" 요청은 `review` + `app-quality-gate` 조합을 기본으로 사용합니다.
- UI 변경 작업은 `ui-testing`과 `swift-ui-expert`를 자동 후보로 평가합니다.
- 테스트 추가/수정 요청은 `testing-patterns`를 반드시 참조합니다.

## Claude Metadata Compatibility

`.claude/agents/*.md`, `.claude/skills/*/SKILL.md`의 YAML frontmatter는 Codex에서 다음처럼 해석합니다.

- `model`, `color`, `memory`, `tools`, `agent` 는 **참고용 메타데이터**로만 취급합니다.
- 실제 사용 모델/도구는 Codex 런타임(시스템 지침 + 현재 사용 가능한 도구) 기준으로 결정합니다.
- 문서 안의 "`Task tool call to ... agent`" 문구는 Claude 전용 표현이므로, Codex에서는 **동일 의도를 현재 도구로 수행**하는 지시로 해석합니다.
- 문서에 명시된 도구가 현재 세션에 없으면, 가장 가까운 대체 도구/절차로 실행하고 그 차이를 짧게 사용자에게 알립니다.
- 상위 지침(시스템/개발자)과 충돌하는 항목은 상위 지침을 우선합니다.

## Permission Parity (`.claude/settings.local.json`)

Codex는 아래 allow list를 Claude와 동일 기준으로 취급합니다(단, 시스템 sandbox 정책이 더 강하면 sandbox 우선).

- WebFetch
- WebSearch
- Bash(git:*)
- Bash(gh:*)
- Bash(bash:*)
- Bash(wc:*)
- Bash(xargs:*)
- Bash(find:*)
- Bash(ls:*)
- Bash(echo:*)
- Bash(python3:*)
- Bash(xcodebuild:*)
- Bash(xcodegen generate:*)
- Bash(xcode-select:*)
- Bash(xcrun:*)
- Bash(brew list:*)
- Bash(brew install:*)
- Bash(/usr/libexec/PlistBuddy:*)
- mcp__sequential-thinking__sequentialthinking
- mcp__plugin_serena_serena__*
- mcp__plugin_context7_context7__*
- mcp__serena__*
- mcp__mcp-deepwiki__*
- mcp__Context7__*

## Path Resolution

- skill/agent 문서에서 상대 경로가 나오면 해당 문서가 위치한 디렉토리를 기준으로 해석합니다.
- 추가 참조가 필요할 때는 참조된 파일만 최소 단위로 읽습니다.
- `.claude/worktrees/*/.claude` 경로로 작업 중인 경우에도 위 규칙을 동일하게 적용합니다.
