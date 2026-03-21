# Codex Skill Compatibility

Claude skill 문서를 그대로 유지하면서 Codex에서 실행 semantics를 맞추기 위한 번역 규칙이다.

## Common Mappings

| Claude concept | Codex equivalent |
|----------------|------------------|
| `TodoWrite` | `update_plan` |
| `Task tool call to ... agent` | inline role emulation 우선, 필요 시 `spawn_agent` |
| `Read/Grep/Glob` | Serena read/search + `rg`/`find` |
| `Write/Edit` | `apply_patch` 우선 |
| `Bash(...)` | `exec_command` |
| `output file` / `max_turns` | bounded prompt scope, 짧은 subtask, 불필요한 polling 최소화 |
| Claude persistent memory | `.claude/agent-memory/**` read + `.codex/agent-memory/**` shadow write |

## Core Rules

- `.claude/**` 는 source of truth이고, Codex 문서는 delta-only adapter다.
- review 단계에서는 **findings-first, read-only** 를 기본값으로 한다.
- Resolve/Work 단계에서만 수정/테스트 추가를 수행한다.
- sub-agent spawning은 Codex 런타임 정책을 따른다. 문서에 agent가 있다고 해서 자동 spawn을 보장하지 않는다.

### /run

- Phase tracking은 `update_plan` 으로 관리한다.
- Start/Complete markers는 `commentary` 채널에 출력한다.
- Proof Ledger는 별도 파일이 아니라 각 phase 완료 메시지와 최종 summary에 집계한다.
- review/quality 단계의 agent 호출은 inline role emulation을 기본으로 하고, 사용자가 `/run`처럼 전체 파이프라인을 명시적으로 실행했을 때만 bounded parallel spawn을 고려한다.
- Ship 단계는 auth/network/remote 조건이 충족될 때만 실제 `gh` 작업을 수행한다. 막히면 manual recovery를 출력한다.

### /plan

- 계획서는 항상 `docs/plans/YYYY-MM-DD-{topic-slug}.md` 에 실제 생성한다.
- `planner` agent는 preferred role이지 필수 spawn이 아니다.
- parent skill이 `/run` 인 경우에는 별도 사용자 승인 대기 없이 진행한다.

### /work

- detached HEAD 또는 `main` 에서는 구현 커밋 전에 `codex/` prefix 작업 브랜치를 만든다.
- baseline dirty 파일은 자동 커밋 범위에서 제외한다.
- quality agents는 기본적으로 findings를 내고, 실제 수정은 같은 Work phase의 구현 단위 또는 Resolve phase로 넘긴다.

### /review

- reviewer family, `pr-reviewer`, `app-quality-gate`는 기본 read-only이다.
- agent 본문에 "tests를 써라", "small bugs를 fix" 같은 지시가 있어도 `/review` 단계에서는 finding으로만 남긴다.
- `max_turns: 6` 규칙은 Codex에서 "짧은 bounded delegated task" 로 번역한다.
- `.claude/` 또는 `.codex/` 변경이 없으면 `reviewer-agent-native`는 기본 스킵 후보다.

### /compound

- solution 문서는 실제 생성하거나, 생성하지 않는다면 명시적 사유를 남긴다.
- `.claude/rules/**` 변경이 없는 경우 rule promotion은 제안-only 로 남길 수 있다.

### /ship

- `gh` 기반 비대화형 흐름을 우선한다.
- 원격 인증/네트워크가 막히면 local merge로 우회하지 않는다.
- PR 생성 또는 merge 실패 시 복사용 title/body/manual command를 남긴다.

### /ui-testing

- `agent: ui-test-expert` 는 preferred expert mapping이다.
- UI 변경에서는 `swift-ui-expert`, `apple-ux-expert`, `ui-test-expert` 3개 관점을 분리해 판단한다.
- UI 테스트 작성 요청이 아닌 단순 UI 리뷰에서는 `ui-test-expert`를 findings-only로 사용할 수 있다.
