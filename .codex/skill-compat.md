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
- prompt에는 절대 workspace 경로, 단일 목표, 대상 파일/관련 diff 경로, 편집 가능 범위, 완료 조건, 이미 수행한 검증을 전달한다. **해당 `.claude/agents/<role>.md`의 정확한 절대 경로와 읽으라는 지시**, 관련 필수 규칙 경로를 포함한다. `fork_turns="none"`은 parent가 읽은 role prompt를 상속하지 않는다.
- parent가 해야 할 독립 작업이 없으면 agent 생성 비용을 피하고 inline으로 처리한다. 이 경우 실제 parent 모델 사용임을 구분하며 모델이 전환됐다고 보고하지 않는다.
- 여러 agent가 같은 파일을 수정하지 않게 소유 범위를 나눈다. 출력은 변경 파일, 검증 결과, P1/P2/P3 findings, 남은 불확실성만 반환한다. 전체 diff/로그를 재출력하지 않는다.
- 해당 phase의 skill은 처음 진입할 때 한 번 읽고, 내용이 바뀌었거나 컨텍스트에서 사라졌을 때만 다시 읽는다. source의 필수 절차는 유지하되 동일 절차를 parent/child가 반복 서술하지 않는다.
- 필수 프로젝트 문서/규칙은 유지한다. 선택적 reference, memory, 과거 solution은 검색으로 관련 부분만 읽으며 모든 skill/agent 문서를 일괄 로드하지 않는다.
- 테스트 실행, 결과 재사용, 비용 측정이 필요할 때만 `.codex/token-efficiency.md`를 읽는다.
- 여러 reviewer/phase가 변경 정보를 공유할 때 `python3 scripts/codex-context.py snapshot --base <실제-base>`로 한 번 저장하고 반환된 디렉터리를 전달한다. `manifest.json`과 담당 patch 구간만 읽는다. 재사용 전 `python3 scripts/codex-context.py check <디렉터리>`로 최신성을 확인한다. untracked/binary 본문과 관련 호출부는 별도로 확인하며, snapshot은 리뷰·테스트 통과 증거가 아니다. 이 수집 작업 자체에는 agent를 생성하지 않는다.

### 재시도와 범위 확장 제한

사용자가 요청한 무의미한 재시도 방지 규칙이다. Claude 원본의 반복 실행 지시보다 이 Codex 실행 한도를 우선한다.

- 실행 전 현재 변경에 필요한 검증인지 확인한다. 문서/도구 작업에서 관성적으로 앱 빌드·전체 UI·smoke를 실행하지 않는다. 필요한 최소 검증을 통과했으면 새 변경/실패 근거 없이 범위를 넓히지 않는다.
- 실패하면 `작업 / 실패 지점·원인 / 새로 확인된 변화 / 재시도 횟수 / 다음 조치`를 짧게 기록한다. 명령 표기, 로그 경로, 모델, phase 또는 대화 turn이 바뀌어도 같은 원인에는 같은 횟수를 적용한다.
- 같은 원인에 대한 자동 재시도는 **최대 1회**다. 원인에 대응한 코드 수정 또는 실패한 의존성의 정상 동작 확인이 먼저 있어야 한다. 시간 경과, 일시적인 부하 하락, 단순 목록 조회 성공, 막연한 기대만으로 재실행하지 않는다. 새 실패 원인으로 횟수를 초기화하려면 기존 원인이 해소됐다는 증거가 있어야 한다.
- 재시도에서도 같은 원인이 남으면 해당 실행 경로를 중단하고 원인·미검증 범위·정확한 재개 조건을 기록한다. 독립적으로 가능한 작업은 계속한다. 환경 실패를 코드 실패/테스트 통과로 보고하지 않으며, 필요한 검증이 막힌 상태로 게이트를 통과시키지 않는다.
- 진행 중인 실행은 복제 실행하지 않는다. 해당 도구의 대기 기능을 사용하고 새 출력이 없으면 반복 로그 읽기·프로세스 조회를 하지 않는다. 상태 조회가 필요할 때는 30~60초 간격으로 하며, 같은 상태가 2회 이어지면 정한 timeout/완료 이벤트를 기다린다. 사용자에게 필요한 진행 안내는 별도로 유지한다.
- 무관한 기존 실패는 이번 작업의 diff에 원인이 있는지 먼저 확인한다. 관계가 없으면 별도 이슈로 기록하고 현재 작업의 검증 범위를 다시 확정한다. 완료 조건을 맞추려고 관계없는 앱/테스트를 수정하거나 검증 중 실행기 파일을 수정하지 않는다.
- 이미 유효한 검증/리뷰가 있으면 같은 내용을 다시 실행하지 않는다. 수정 후 재리뷰는 바뀐 부분과 영향을 받는 관점만 수행하고 기존 결과의 유효 범위를 함께 기록한다. 실행만을 위한 agent 생성, 변화 없는 agent 재호출, 해결 근거 없는 모델 상향을 하지 않는다.

### /run

- Phase tracking은 사용 가능한 계획 도구 또는 phase 상태 기록으로 관리한다.
- Start/Complete markers는 `commentary` 채널에 출력한다.
- Proof Ledger는 별도 파일이 아니라 각 phase 완료 메시지와 최종 summary에 집계한다.
- review/quality 단계는 공통 위임 정책과 agent-map을 따른다. 각 필수 관점의 판단/결과는 유지한다.
- Work의 테스트와 Quality 결과를 뒤 phase에서 다시 사용할 때는 `.codex/token-efficiency.md`의 증거 일치 조건을 확인한다. 유효한 동일 검증은 재실행 대신 evidence 경로를 기록한다. 이는 phase 생략이 아니며, 변경/누락된 검증은 실행한다.
- `/run` 안의 `/work`는 구현/QC까지만 담당하고 Compound/Ship는 parent가 한 번 수행한다. UI 최종 범위는 아래 변경 범위 기반 UI 게이트로 결정한다. full로 판정된 검증은 smoke로 대체하지 않는다.
- `/run` parent가 검증/리뷰 관점별 실행 담당을 한 번 배정한다. Work에서 완료한 전문 검토는 Phase 3.5에서 증거·대상·환경의 유효성을 확인해 재사용하고, 이후 변경으로 영향을 받는 관점만 다시 수행한다. Phase 3.5의 적용 여부 판단과 결과 보고는 유지하며, standalone `/work`의 검증 의무는 바꾸지 않는다.
- phase 상태·증거·문서 확인 이력은 `scripts/codex-pipeline.py`로 기록/검사한다(사용법은 `.codex/token-efficiency.md`). 기록의 존재만으로 완료를 선언하지 않는다. 원문과 adapter를 이번 실행에 적용한 판단은 parent가 유지하며, 문서 hash 확인은 원문 읽기/이해의 대체가 아니다. tool의 compact report를 바탕으로 필수 시작/완료 안내와 최종 증빙을 집계하고 같은 로그/절차를 반복 서술하지 않는다.
- Ship 단계는 auth/network/remote 조건이 충족될 때만 실제 `gh` 작업을 수행한다. 막히면 manual recovery를 출력한다.

#### 변경 범위 기반 UI 게이트

사용자가 승인한 UI 검증 비용 개선에 따른 Codex 전용 실행 예외다. Claude 원본 S11 및 Phase 2.5의 무조건 full 요구를 다음 범위 판정으로 대체한다. Phase 자체나 결과 보고는 생략하지 않는다. `.claude/**` 원본과 Claude 실행 정책은 유지한다.

1. Phase 1에서 `python3 scripts/plan-ui-tests.py --base main`으로 계획하고, Phase 2.5 및 Resolve 후 최종 변경 상태에서 다시 실행한다. 출력 JSON은 로그 디렉터리에 저장한다. base가 다른 작업은 실제 PR base를 지정한다. merge-base부터 tracked 현재 상태, untracked 파일, 삭제/rename 양쪽 경로가 포함된다. Git 실패를 변경 없음으로 취급하지 않는다.
2. 파일별 이유, 플랫폼별 `skip/targeted/full`, 명령 argv를 검토한다. 판정기는 의존성 분석/테스트 실행/통과 인증기가 아니다. 변경 symbol의 다른 feature 소비자를 `rg` 또는 심볼 도구로 확인하고, 선택 범위를 벗어나거나 영향이 불명확하면 full로 상향한다. 새 화면/동작의 테스트가 없으면 작성한다. View 파일명만으로 판단하지 않는다.
3. 기본 범위:
   - 문서/지침 Markdown만 변경: UI `skipped`, 경로와 근거 기록. 앱 리소스 안의 Markdown은 면제하지 않는다.
   - unit test Swift 파일만 변경: 관련 unit 검증, UI `skipped`.
   - UI 게이트 판정기/CLI 선택/로그 검증 및 해당 계약 테스트만 변경: Python 계약 테스트, shell 구문, dry-run argv와 diff 리뷰로 검증하고 앱 UI는 `skipped`. 도구 수정 자체를 이유로 전체 UI나 공통 smoke를 실행하지 않는다. 판정기의 정확한 tooling 경로 목록은 검증 의무를 표시하며, 실행/설치/seed/기기 선택/CI 실행 환경 변경이 포함되면 영향을 받는 통합 검증으로 상향한다.
   - Codex snapshot/receipt/pipeline/parity 도구와 정확히 매핑된 계약 테스트만 변경: 해당 Python 계약·parity 검증과 diff 리뷰를 수행한다. watch 실행기의 로그/결과 검증만 변경한 경우도 tooling 검증 대상이다. 파일 경로 면제는 잠정 분류이며 실행 명령·설치·seed·기기·CI 변경이 없는지 확인해야 한다. 미매핑 script는 기존 full fallback을 유지한다.
   - 매핑된 feature 화면/ViewModel: 관련 UI suite + 공통 smoke 합집합. `test-ui.sh --smoke --only-testing DUNEUITests/ClassName`를 사용한다. CLI는 디렉터리명이 아닌 실제 class/method selector를 받는다.
   - App/Domain/Data/Shared, 내비게이션/전역 테마/저장/프로젝트 설정, 공유 test helper 또는 미매핑 변경: 영향 플랫폼 full. watch는 별도 runner로 검증한다. 공유 소스/플랫폼이 불명확하면 iOS/watch 모두 full로 올리고 widget/visionOS 등 추가 타깃도 확인한다.
   - 화면 영향이 없는 순수 계산 로직: 자동 면제하지 않는다. 호출부 분석으로 UI/저장/공유 소비자에 영향이 없음을 증명하고 관련 단위 테스트 통과를 기록한 경우에만 UI `skipped` 판단 가능하다. 근거가 부족하면 full 유지.
   - nightly/릴리스 전: 전체 회귀 유지. HealthKit 권한 등 full plan의 기존 manual 제외는 별도 실제 기기 검증을 요구한다.
4. `--smoke`만 실행해서 변경 기능 검증을 대체하지 않는다. 테스트 선택이 새 동작 커버리지를 증명하지 않는다. 제스처/차트의 seeded lifecycle, 번역/Dynamic Type/iPad/watch 등 해당 변경의 기존 검증 의무를 유지한다.
5. 완료 증빙: 변경 경로/판정 이유, 실제 명령·plan·기기, 결과 로그, 수행/skip 수, 관련 suite 실행 여부를 기록한다. UI가 필요한데 미실행/0개/unknown count/필수 suite 누락/실패면 게이트 실패다. 정당한 UI 면제는 `skipped`로 기록하고 “UI 통과/레이아웃 확인 완료”라고 보고하지 않는다.
6. 수정 중에는 실패 관련 테스트부터 확인한다. 최종 변경 상태에 필요한 범위가 모두 통과해야 Review/Ship로 진행한다. 동일 성공 증거 재사용은 `.codex/token-efficiency.md` 조건을 따르며 targeted 성공을 full 증거로 승격하지 않는다.
7. 자동 판정 범위를 축소한 경우 근거와 대체 검증을 Proof Ledger에 남긴다. 인프라 변경은 실행기 fixture/구문/parity 검증도 수행한다. 빌드, 리뷰, Compound, Ship의 다른 게이트는 유지한다.
   - 앱 소스·프로젝트·UI test body·seed/helper가 동일한 CLI 선택 변경은 fixture와 dry-run 검증 결과 및 앱 관련 diff 없음으로 증빙한다. 검증 도중 발견한 무관한 기존 UI 실패를 수정하느라 작업 범위를 확장하지 않는다. 중단한 UI 실행은 통과 증거가 아니며 이번 도구 작업의 완료 조건으로 삼지 않는다.

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
- `.claude/`와 `.codex/` 하위 지침만 변경된 경우 source의 역방향 스킵을 적용해 Agent-Native만 실행한다. 앱/실행 스크립트와 혼합된 변경은 이에 해당하지 않는다.

### /compound

- solution 문서는 실제 생성하거나, 생성하지 않는다면 명시적 사유를 남긴다.
- `.claude/rules/**` 변경이 없는 경우 rule promotion은 제안-only 로 남길 수 있다.

### /ship

- `gh` 기반 비대화형 흐름을 우선한다.
- 최종 PR reviewer는 이전 리뷰 증거/미해결 findings와 그 이후 변경분을 우선 확인한다. 이전 증거가 없거나 범위/기준이 다르면 전체 대상 diff를 검토한다. 최종 통합/크래시 위험 게이트는 유지한다.
- 원격 인증/네트워크가 막히면 local merge로 우회하지 않는다.
- PR 생성 또는 merge 실패 시 복사용 title/body/manual command를 남긴다.

#### Ship 시뮬레이터 정리

- 테스트 실행 전 존재하는 simulator UDID 목록을 기준선으로 기록한다. 해당 worktree/branch 작업에서 새로 생성한 simulator의 UDID, 이름, worktree 절대 경로, branch 및 생성 명령 성공 기록을 남긴다. **작업 시작 전에 존재하던 기기는 사용·재사용 여부와 무관하게 삭제 대상에서 제외한다.** clone 실패로 fallback한 원본도 제외한다.
- Step 1에서 생성 전 기준선과 생성 성공 기록을 대조하여 해당 worktree/branch 작업에서 새로 생성하고 사용한 UDID만 수집한다. 신규 생성 여부를 확인할 증거가 없으면 삭제하지 않는다. Step 3의 **원격 머지 성공을 확인한 직후**, Step 4의 checkout 및 worktree 제거 전에 아래 정리를 수행한다. `/run`에서 호출된 Ship에도 동일하게 적용한다.
- 새로 생성하고 사용한 simulator가 없으면 정리를 건너뛴다. 머지 실패 시에는 디버깅/재시도를 위해 유지한다.
- `xcrun simctl list devices -j`로 각 UDID의 존재와 이름을 확인하고, 현재 작업 전용으로 소유가 확인된 기기만 정리한다. 이미 삭제된 UDID는 완료로 취급한다. 기본 기기, 다른 작업이 사용하는 기기, 소유 관계가 불명확한 기기는 보존하고 이유를 보고한다.
- 현재 helper는 worktree의 basename으로 이름을 구성하므로 서로 다른 경로가 모두 `Health`로 끝나면 이름이 충돌한다. `git worktree list --porcelain`과 생성/사용 기록을 대조하며, 이름의 `-wt-Health` 포함 여부만으로 소유를 판단하지 않는다. 사용 기록만으로 독점 소유가 입증되지 않으면 삭제하지 않는다.
- 확인된 UDID마다 `xcrun simctl shutdown "$udid"` 후 Shutdown 상태를 확인하고 `xcrun simctl delete "$udid"`를 실행한다. 이미 Shutdown인 상태는 허용한다. 종료 또는 삭제가 실패하면 해당 기기는 미정리로 기록하고 나머지 대상 및 Ship 후속 단계를 계속한다.
- Ship에서는 `--cleanup-all`, `simctl delete all`, 이름 패턴 기반 `--cleanup-current` / `--cleanup-simulators`를 사용하지 않는다. 삭제 후 전체 기기 목록을 다시 조회하여 해당 UDID가 사라졌는지 확인한다.
- 최종 결과에 삭제한 기기 수와 남은 기기/사유를 포함한다. 목록 조회나 삭제 실패를 정리 성공으로 보고하지 않는다.

### /ui-testing

- `agent: ui-test-expert`는 agent-map의 실제 모델 배정을 사용한다. 테스트 실행 자체에는 agent가 필요 없다.
- Unit/UI/watch 테스트는 기존 `scripts/test-unit.sh`, `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`를 표준 경로로 사용한다. 기본 파일 로그/요약을 유지하고 필요한 때만 streaming한다.
- 개발 중 관련 테스트를 먼저 실행하고 `/run`은 위 변경 범위 기반 UI 게이트, 그 외는 source skill의 최종 필수 범위를 검증한다. 동일 검증의 재사용 조건은 `.codex/token-efficiency.md`를 따른다.
- UI 변경에서는 `swift-ui-expert`, `apple-ux-expert`, `ui-test-expert` 3개 관점을 분리해 판단한다.
- UI 테스트 작성 요청이 아닌 단순 UI 리뷰에서는 `ui-test-expert`를 findings-only로 사용할 수 있다.
