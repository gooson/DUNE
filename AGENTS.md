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
- cleanup: 머지 완료된 워크트리와 로컬 브랜치 일괄 정리. (file: /Users/shanks/work/Health/.claude/skills/cleanup/SKILL.md)
- code-style: 코드 스타일/컨벤션 참조. (file: /Users/shanks/work/Health/.claude/skills/code-style/SKILL.md)
- compound: 해결된 문제를 docs/solutions 에 문서화. (file: /Users/shanks/work/Health/.claude/skills/compound/SKILL.md)
- copy-voice: 문서/UI 문구 톤앤매너 가이드. (file: /Users/shanks/work/Health/.claude/skills/copy-voice/SKILL.md)
- debug: 재현->격리->가설->검증->수정->확인->문서화 디버깅 루프. (file: /Users/shanks/work/Health/.claude/skills/debug/SKILL.md)
- design-system: UI/UX 디자인 시스템 가이드. (file: /Users/shanks/work/Health/.claude/skills/design-system/SKILL.md)
- run: Plan->Work->Review->Resolve->Compound->Ship 전체 파이프라인 자동 실행. (file: /Users/shanks/work/Health/.claude/skills/run/SKILL.md)
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

- /Users/shanks/work/Health/.claude/rules/asset-catalog.md
- /Users/shanks/work/Health/.claude/rules/build-pipeline.md
- /Users/shanks/work/Health/.claude/rules/compound-workflow.md
- /Users/shanks/work/Health/.claude/rules/design-system-rules.md
- /Users/shanks/work/Health/.claude/rules/documentation-standards.md
- /Users/shanks/work/Health/.claude/rules/healthkit-patterns.md
- /Users/shanks/work/Health/.claude/rules/input-validation.md
- /Users/shanks/work/Health/.claude/rules/localization.md
- /Users/shanks/work/Health/.claude/rules/mcp-utilization.md
- /Users/shanks/work/Health/.claude/rules/navigation-ownership.md
- /Users/shanks/work/Health/.claude/rules/performance-patterns.md
- /Users/shanks/work/Health/.claude/rules/resource-management.md
- /Users/shanks/work/Health/.claude/rules/swift-layer-boundaries.md
- /Users/shanks/work/Health/.claude/rules/swiftdata-cloudkit.md
- /Users/shanks/work/Health/.claude/rules/swiftui-patterns.md
- /Users/shanks/work/Health/.claude/rules/testing-required.md
- /Users/shanks/work/Health/.claude/rules/todo-conventions.md
- /Users/shanks/work/Health/.claude/rules/watch-navigation.md
- /Users/shanks/work/Health/.claude/rules/watch-ios-parity.md

## Trigger Rules (Parity)

- 사용자 입력에 `/brainstorm`, `/plan`, `/work`, `/review`, `/triage`, `/compound`, `/ship`, `/run`, `/debug`, `/onboard`, `/retrospective`, `/changelog`, `/cleanup` 가 포함되면 동일 이름 skill을 우선 적용합니다.
- 사용자가 특정 agent 이름(예: `reviewer-security`, `swift-ui-expert`)을 직접 언급하면 해당 `.claude/agents/{name}.md`를 우선 적용합니다.
- "리뷰해줘/품질 검토/출시 전 점검" 요청은 `review` + `app-quality-gate` 조합을 기본으로 사용합니다.
- UI 변경 작업은 `ui-testing`과 `swift-ui-expert`를 자동 후보로 평가합니다.
- 다국어/i18n/localization/번역 문자열 변경 요청은 `.claude/rules/localization.md`를 반드시 참조합니다.
- 테스트 추가/수정 요청은 `testing-patterns`를 반드시 참조합니다.

## Claude Metadata Compatibility

`.claude/agents/*.md`, `.claude/skills/*/SKILL.md`의 YAML frontmatter는 Codex에서 다음처럼 해석합니다.

- `model`, `color`, `memory`, `tools`, `agent` 는 **참고용 메타데이터**로만 취급합니다.
- 실제 사용 모델/도구는 Codex 런타임(시스템 지침 + 현재 사용 가능한 도구) 기준으로 결정합니다.
- 문서 안의 "`Task tool call to ... agent`" 문구는 Claude 전용 표현이므로, Codex에서는 **동일 의도를 현재 도구로 수행**하는 지시로 해석합니다.
- 문서에 명시된 도구가 현재 세션에 없으면, 가장 가까운 대체 도구/절차로 실행하고 그 차이를 짧게 사용자에게 알립니다.
- 상위 지침(시스템/개발자)과 충돌하는 항목은 상위 지침을 우선합니다.

## Codex Adapter Layer

### 브랜치 핵심 검증과 프로세스 점유

- **`run`을 포함한 모든 스킬**에서 `.codex/skill-compat.md`의 **모든 스킬의 핵심 검증과 점유 예산**을 우선 적용한다. 원본의 무조건 전체 테스트·반복 재빌드 요구에 대한 명시적 사용자 예외다. 변경 동작·소비자·영향 플랫폼을 확인해 정확한 unit/UI selector만 실행하며, 로컬 전체 회귀는 사용자가 명시적으로 요청한 경우에만 실행한다. 요청하지 않은 full을 필수 미완료 게이트로 남기지 않는다.
- 한 worktree의 build/unit/UI/capture는 한 번에 하나만 실행한다. 표준 실행기의 로컬 기본값은 build jobs 2·index store OFF·test 병렬 실행 OFF이며 CI 정책은 유지한다. build/unit에도 소유 프로세스 deadline을 적용하고, 동일 증거는 phase가 바뀌어도 재사용한다. 자세한 예산·종료·재시도·캐시 기준은 위 canonical 문서를 따른다.
- **Mac 화면 잠금은 검증 중단 사유가 아니다.** 잠금 해제 요청이나 대기 전환 전에 `.codex/ui-execution.md`의 잠금 상태 성공 근거와 백그라운드 XCTest·guest PNG·필요한 CLI/readback 경로를 확인한다. 실제 실패 단계·명령/오류·미검증 범위 없이 “화면이 잠겨서 불가”라고 보고하지 않는다. 사용자 인증을 우회하거나 다른 작업의 기기를 조작하지 않는다.

### UX Writing

- 사용자 대면 문구를 작성·수정·검토할 때 `copy-voice`와 함께 [UX Writing 보완 규칙](.codex/ux-writing.md)을 읽는다. 해당 문서가 제목·본문·버튼의 역할, 의미 중복, 행동명, 실제 상태 표현, Watch 길이 기준의 Codex 적용 기준이다.
- `.claude/skills/copy-voice/SKILL.md` 원본은 유지한다. 단어 수 상한·일괄 오류 표현·고정 번역 길이 비율 등과 충돌하면 위 보완 규칙의 명시적인 대체 기준을 따른다. 기존 localization·디자인맵 검증 의무는 유지한다.

### String Catalog Format

- `Localizable.xcstrings` 또는 `InfoPlist.xcstrings`에 항목을 생성하거나 수정한 뒤 `swift scripts/format-xcstrings.swift`를 실행합니다. Shared·Watch Localizable 및 Watch InfoPlist 카탈로그를 Xcode의 JSON 직렬화 형식으로 정렬하며 번역 값은 변경하지 않습니다.
- 변경 전후와 빌드 후에는 `swift scripts/format-xcstrings.swift --check --check-manual`로 포맷과 모든 항목의 `extractionState: manual`을 확인합니다. 파일 하나만 검사하거나 정리할 때는 명령 끝에 해당 경로를 전달합니다. formatter는 추출 상태나 번역을 자동 수정하지 않습니다.
- `InfoPlist.xcstrings`를 추가하면 Xcode가 해당 타깃의 앱 이름과 권한 설명도 추출합니다. `Info.plist`와 `project.yml`의 관련 값을 함께 등록하고 `python3 -B -m unittest scripts.tests.test_format_xcstrings`로 누락과 Xcode sync 불변성을 검사합니다.
- 문자열 보간 키는 코드가 의도한 `%lld`와 실제 추출된 `%@`가 다를 수 있습니다. 실제 추출 키를 확인하고 번역의 보간 타입·인자 순서를 맞춥니다. 빌드 전후 검사 또는 커밋 검사 실패를 카탈로그 되돌리기나 자동 추출 비활성화로 숨기지 않습니다.

- 사용자 요청으로 개선한 Codex UI 게이트는 모든 스킬에서 `.codex/skill-compat.md`의 **변경 범위 기반 UI 게이트**를 따른다. 이 명시적 예외는 Claude 원본의 S11 및 Phase 2.5 전체 UI 강제 실행보다 우선한다. `.claude/**` 원본은 변경하지 않으며, Claude에서 직접 실행하는 정책은 유지된다.
- 무의미한 재시도·토큰 낭비 방지는 `.codex/skill-compat.md`의 **재시도와 범위 확장 제한**을 따른다. 같은 실패는 원인에 대응한 변화가 확인된 경우에만 최대 1회 재시도한다. 이 제한은 phase/turn 전환 후에도 유지하고, 무관한 UI 실패 수정·전체 재검증으로 작업 범위를 넓히지 않는다.
- Codex의 UI 테스트는 `.codex/skill-compat.md`의 **UI 실행 점유 제한**을 따른다. 표준 실행기와 소유 프로세스 deadline을 사용하고, 한 번에 한 시뮬레이터 실행만 유지한다. 진행 중인 실행을 다시 시작하거나 결과 정리를 무기한 기다리지 않는다.
- 시뮬레이터는 `.codex/skill-compat.md`의 **전용 시뮬레이터 사용**을 따른다. 현재 worktree 소유로 등록된 기기를 단독 사용하며, 테스트·수동 캡처·Duo 자세 전환에도 같은 소유권 기준을 적용한다.

- `.claude/**` 는 **수정하지 않는 source of truth** 입니다. Codex 전용 번역/보강은 `.codex/**` 와 `AGENTS.md` 에만 기록합니다.
- Codex 실행 adapter 문서는 다음 3개를 기준으로 유지합니다.
  - `.codex/agent-map.md`
  - `.codex/skill-compat.md`
  - `.codex/agent-memory/README.md`
- 공통 실행 규칙(`Task tool`, `TodoWrite`, read-only review, memory policy)은 `.codex/skill-compat.md` 를 canonical source로 사용합니다.
- `/cleanup` 및 `/ship`에서 worktree를 제거하기 전에 `.codex/skill-compat.md`의 **외부 DerivedData 정리** 절차로 해당 worktree 소유 캐시만 함께 삭제합니다. `info.plist`의 `WorkspacePath`로 소유를 확인하며 다른 worktree·main·공용·소유 미확인 캐시는 보존합니다.
- 사용자 요청으로 머지 관측 후 로컬 정리를 자동 실행합니다. `.codex/skill-compat.md`의 **머지 관측 후 자동 정리 hook**을 따르며 `python3 scripts/cleanup-merged-worktrees.py --install`로 설치합니다. fetch/pull의 main 갱신에서 PR 커밋 증거가 있는 브랜치·깨끗한 비활성 worktree만 정리하며 현재/primary/dirty/locked worktree는 보존합니다.
- agent별 모델/추론/edit policy/memory source는 `.codex/agent-map.md` 를 canonical source로 사용합니다.
- 모델 분담과 토큰 절감 실행은 `.codex/skill-compat.md`의 공통 정책을 따릅니다. 위임 시 `.codex/agent-map.md`의 모델을 실제 호출 인자로 전달하며, 테스트/검증 재사용 시에만 `.codex/token-efficiency.md`를 읽습니다. 문서 배정은 현재 작업이나 앱 전역 모델을 자동 변경하지 않습니다.
- `.claude/agents/*.md` 또는 핵심 skill 목록이 바뀌면 Codex adapter 문서를 함께 갱신하고 `python3 scripts/check-codex-claude-parity.py` 로 drift를 검사합니다.

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

## Duo Simulator Automation Memory

- Duo 전환/회전 작업은 `.codex/agent-memory/ui-test-expert.md`를 먼저 읽습니다.
- GUI 잠금이나 `simctl`의 접힘 명령 부재만으로 백그라운드 전환 검증이 불가능하다고 판단하지 않습니다. 검토한 CLI와 공식 `devicectl` 하위 명령을 확인하고, 실제 상태 readback과 viewport/PNG로 성공을 검증합니다.

## Actual Design Map Sync

- 모든 디자인 작업은 변경 전 해당 화면의 레이아웃 맵과 [테마 맵](docs/design/theme-map/index.html)에서 배치·표현 기준을 먼저 확인하거나 갱신합니다. 4탭 루트는 [4탭 레이아웃 맵](docs/design/layout-map/index.html)을 사용하고, 그 밖의 새 화면·레이아웃은 별도 맵을 `docs/design/layout-map/`에 만들고 인덱스에서 연결한 뒤 구현합니다. 코드·실제 캡처가 맵과 다르면 같은 작업에서 차이를 해소합니다. 시안과 실제 캡처는 구분합니다. 세 맵의 역할과 순서는 [레이아웃 맵 유지 방법](docs/design/layout-map/README.md)을 따릅니다.

- 앱의 화면 배치·문구·상태·내비게이션을 수정하면 같은 작업에서 [통합 실제 화면 디자인맵](docs/design/phone-design-map/actual/index.html)의 해당 화면을 다시 캡처하고 갱신합니다. 일반 iPhone, iPad, Duo 접힘·펼침, Watch 중 영향받는 기기만 실행하되, 영향을 받는 상태와 기기를 명시적으로 확인합니다.
- 기존 PNG를 새 화면의 증거로 재사용하지 않습니다. 캡처할 수 없으면 갱신되지 않은 화면 ID와 이유를 결과에 명시하고 완료된 캡처로 표시하지 않습니다. 실행 절차는 [디자인맵 유지 방법](docs/design/phone-design-map/README.md)의 「화면 수정 시 갱신」을 따릅니다.
- Codex의 UI 검증 범위 판정과 디자인맵 갱신 의무는 별개입니다. 세부 게이트는 `.codex/skill-compat.md`를 따릅니다. `.claude/**` 원본은 변경하지 않습니다.

## Theme Map Sync

- 테마 방향 시안의 색·배경·능선·링·그래프·움직임·화면별 표현을 변경하거나 새 테마를 추가하면 같은 작업에서 [테마 맵](docs/design/theme-map/index.html)의 보존본, `manifest.json`, README를 갱신하고 `python3 docs/design/theme-map/build-theme-map.py`를 실행합니다.
- 대화용 외부 시안 파일만 수정한 채 끝내지 않습니다. 저장소 안의 `docs/design/theme-map/themes/`에 최신 시안을 보존하고 `python3 docs/design/theme-map/build-theme-map.py --check`로 맵 동기화를 확인합니다.
- 테마 방향 시안은 실제 앱 캡처가 아닙니다. 앱 UI까지 변경한 경우에는 위 Actual Design Map Sync도 별도로 적용합니다.
