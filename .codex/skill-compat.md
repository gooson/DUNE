# Codex Skill Compatibility

Claude skill 문서를 그대로 유지하면서 Codex에서 실행 semantics를 맞추기 위한 번역 규칙이다.

## Common Mappings

| Claude concept | Codex equivalent |
|----------------|------------------|
| `TodoWrite` | 사용 가능한 계획 도구, 없으면 간결한 phase 상태 기록 |
| `Task tool call to ... agent` | 아래 공통 위임 정책 + `spawn_agent` |
| `Read/Grep/Glob` | Serena read/search + `rg`/`find` |
| `Write/Edit` | `apply_patch` 우선 |
| `Bash(...)` | `exec_command` |
| `output file` / `max_turns` | bounded prompt scope, 짧은 subtask, 불필요한 polling 최소화 |
| Claude persistent memory | `.claude/agent-memory/**` read + `.codex/agent-memory/**` shadow write |

## Core Rules

- `.claude/**` 는 source of truth이고, Codex 문서는 delta-only adapter다.
- review 단계에서는 **findings-first, read-only** 를 기본값으로 한다.
- Resolve/Work 단계에서만 수정/테스트 추가를 수행한다.
- sub-agent spawning은 Codex 런타임 정책을 따른다. 이 정책은 독립적으로 실행 가능한 구현/테스트/리뷰 하위 작업의 모델 분담을 요청한다. 단순 셸 실행이나 한 줄 수정은 별도 agent를 만들지 않는다.

## 공통 위임 / 컨텍스트 정책

- 위임 시 `.codex/agent-map.md`의 모델과 추론 강도를 `spawn_agent`의 `model`, `reasoning_effort`에 **명시**한다. `fork_turns="none"`으로 대화 전체를 복제하지 않는다. 문서의 모델 배정은 실제 호출 인자를 생략할 근거가 아니다.
- prompt에는 절대 workspace 경로, 단일 목표, 대상 파일/관련 diff 경로, 관련 규칙, 편집 가능 범위, 완료 조건, 이미 수행한 검증만 전달한다. source agent prompt와 필수 프로젝트 규칙은 계속 적용한다.
- parent가 해야 할 독립 작업이 없으면 agent 생성 비용을 피하고 inline으로 처리한다. 이 경우 실제 parent 모델 사용임을 구분하며 모델이 전환됐다고 보고하지 않는다.
- 여러 agent가 같은 파일을 수정하지 않게 소유 범위를 나눈다. 출력은 변경 파일, 검증 결과, P1/P2/P3 findings, 남은 불확실성만 반환한다. 전체 diff/로그를 재출력하지 않는다.
- 해당 phase의 skill은 처음 진입할 때 한 번 읽고, 내용이 바뀌었거나 컨텍스트에서 사라졌을 때만 다시 읽는다. source의 필수 절차는 유지하되 동일 절차를 parent/child가 반복 서술하지 않는다.
- 필수 프로젝트 문서/규칙은 유지한다. 선택적 reference, memory, 과거 solution은 검색으로 관련 부분만 읽으며 모든 skill/agent 문서를 일괄 로드하지 않는다.
- 테스트 실행, 결과 재사용, 비용 측정이 필요할 때만 `.codex/token-efficiency.md`를 읽는다.

### /run

- Phase tracking은 사용 가능한 계획 도구 또는 phase 상태 기록으로 관리한다.
- Start/Complete markers는 `commentary` 채널에 출력한다.
- Proof Ledger는 별도 파일이 아니라 각 phase 완료 메시지와 최종 summary에 집계한다.
- review/quality 단계는 공통 위임 정책과 agent-map을 따른다. 각 필수 관점의 판단/결과는 유지한다.
- Work의 테스트와 Quality 결과를 뒤 phase에서 다시 사용할 때는 `.codex/token-efficiency.md`의 증거 일치 조건을 확인한다. 유효한 동일 검증은 재실행 대신 evidence 경로를 기록한다. 이는 phase 생략이 아니며, 변경/누락된 검증은 실행한다.
- `/run` 안의 `/work`는 구현/QC까지만 담당하고 Compound/Ship는 parent가 한 번 수행한다. 최종 full UI 회귀 게이트를 smoke로 대체하지 않는다.
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
- `max_turns: 6`은 런타임에 해당 인자가 없으면 하드 제한이라고 주장하지 않는다. 한정된 diff/관련 파일과 findings-only 출력으로 작업을 제한한다.
- 5~6개 관점에 필요한 diff를 한 번 수집하고 각 reviewer에는 담당 변경과 관련 호출부를 전달한다. cross-file 영향 검증을 막을 정도로 파일 범위를 제한하지 않는다.
- `.claude/` 또는 `.codex/` 변경이 없으면 `reviewer-agent-native`는 기본 스킵 후보다.

### /compound

- solution 문서는 실제 생성하거나, 생성하지 않는다면 명시적 사유를 남긴다.
- `.claude/rules/**` 변경이 없는 경우 rule promotion은 제안-only 로 남길 수 있다.

### /ship

- `gh` 기반 비대화형 흐름을 우선한다.
- 최종 PR reviewer는 이전 리뷰 증거/미해결 findings와 그 이후 변경분을 우선 확인한다. 이전 증거가 없거나 범위/기준이 다르면 전체 대상 diff를 검토한다. 최종 통합/크래시 위험 게이트는 유지한다.
- 원격 인증/네트워크가 막히면 local merge로 우회하지 않는다.
- PR 생성 또는 merge 실패 시 복사용 title/body/manual command를 남긴다.

### /ui-testing

- `agent: ui-test-expert`는 agent-map의 실제 모델 배정을 사용한다. 테스트 실행 자체에는 agent가 필요 없다.
- Unit/UI/watch 테스트는 기존 `scripts/test-unit.sh`, `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`를 표준 경로로 사용한다. 기본 파일 로그/요약을 유지하고 필요한 때만 streaming한다.
- 개발 중 관련 테스트를 먼저 실행하고 source skill의 최종 필수 범위를 검증한다. 동일한 전체 검증의 재사용 조건은 `.codex/token-efficiency.md`를 따른다.
- UI 변경에서는 `swift-ui-expert`, `apple-ux-expert`, `ui-test-expert` 3개 관점을 분리해 판단한다.
- UI 테스트 작성 요청이 아닌 단순 UI 리뷰에서는 `ui-test-expert`를 findings-only로 사용할 수 있다.
