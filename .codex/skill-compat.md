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
- **모든 스킬의 브랜치 검증은 아래 핵심 검증·점유 예산을 우선 적용한다.** `/run` 전용 예외가 아니다. 원본 skill/agent/rule의 무조건 전체 테스트·별도 재빌드·기계적 반복 요구와 충돌하면 이 명시적 사용자 예외를 따른다. `.claude/**`는 수정하지 않는다.
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
- 세션 비용 감사는 원문을 모델에 일괄 로드하지 않고 `scripts/audit-agent-sessions.py`로 기간별 usage를 집계한 뒤 상위 세션의 필요한 구간만 확인한다. 캐시·reasoning·중복 기록 해석은 `.codex/token-efficiency.md`를 따른다.
- 여러 reviewer/phase가 변경 정보를 공유할 때 `python3 scripts/codex-context.py snapshot --base <실제-base>`로 한 번 저장하고 반환된 디렉터리를 전달한다. `manifest.json`과 담당 patch 구간만 읽는다. 재사용 전 `python3 scripts/codex-context.py check <디렉터리>`로 최신성을 확인한다. untracked/binary 본문과 관련 호출부는 별도로 확인하며, snapshot은 리뷰·테스트 통과 증거가 아니다. 이 수집 작업 자체에는 agent를 생성하지 않는다.

### 실행 검증 수집 위임

- 단일 명령 실행·대기·정해진 캡처 저장은 셸로 처리한다. 화면 진입·예상 상태 readback·여러 캡처 수집처럼 언어 판단이 필요하고 parent가 독립 작업을 병행할 수 있을 때만 `ui-test-expert` 실행 수집 모드를 사용한다. 모델·추론 배정은 `agent-map.md`를 따른다. 독립 작업이 없으면 inline으로 수행하며 parent 모델이 바뀌었다고 보고하지 않는다.
- parent는 실행 전에 검증 범위, 정확한 plan/selector, 현재 worktree 전용 기기, locale/seed/앱 상태, 예상 화면 ID와 캡처 목록, 출력 경로, 완료·중단 조건을 확정한다. 대화 전체 대신 이 작업 계약과 역할·관련 규칙 경로만 전달한다. Duo 전환은 지정 memory와 상태 readback·viewport/PNG 증거 규칙도 전달한다.
- 수집 모드는 source `ui-test-expert`의 테스트 작성·수정 지시보다 좁은 역할이다. 허용된 기기 조작과 증거 저장만 수행하고 테스트 설계, 범위 확대, 코드 수정, 시각적 품질 승인, Ship 판단은 하지 않는다. 이미지/조작 도구나 지정 모델이 지원되지 않으면 대안·이유와 미수행 범위를 기록한다.
- 위임 후에도 전용 시뮬레이터 소유권, 표준 실행기, 저장소 잠금, deadline, 최대 1회 조건부 재시도를 유지한다. parent와 child가 같은 runner/기기를 동시에 조작하지 않는다. 다른 agent가 앱·테스트·seed·실행 입력을 바꾸면 해당 실행 증거의 유효성을 다시 확인하고 기존 성공을 최종 상태에 재사용하지 않는다.
- 수집 모드의 결과 형식은 source 역할의 매 응답 리뷰 템플릿(Findings/Missing Test Cases/iPad-Specific Risks/Coverage Rating)을 대신해 `token-efficiency.md`의 수집 결과 계약만 따른다. parent는 기기·실제 이미지와 출처 및 테스트 실행을 맡긴 경우 receipt·selector를 확인해 필요한 게이트를 판단한다. 예상 상태 불일치·불충분한 증거는 기존 자료와 함께 담당 전문가에게 넘긴다. 모델 상향이나 phase 전환으로 재시도 횟수를 초기화하거나 자동 재실행하지 않는다.

### 모든 스킬의 핵심 검증과 점유 예산

2026-10-30 사용자 요청에 따른 Codex 로컬 브랜치 기본값이다. 테스트 개수보다 **변경한 동작·실패 위험을 직접 확인하는지**로 범위를 정한다. CI/nightly 설정을 이 문서로 변경하지 않는다.

1. 실행 전 `변경 동작 → 영향받는 호출부/플랫폼 → 검증할 성공·실패/경계 조건 → 정확한 selector/명령 → 종료 조건`을 짧게 정한다. 실제 PR base와 현재 dirty/untracked 변경까지 확인한다. 파일명이나 가장 가까운 테스트 하나만으로 영향 범위를 결정하지 않는다.
2. 문서·지침만 변경하면 diff/참조/parity만 확인한다. 도구 변경은 해당 계약 테스트·구문·dry-run을 확인한다. 앱이 바뀌지 않았으면 앱 빌드·시뮬레이터·smoke·캡처를 실행하지 않는다. 설치·부팅·기기 선택 등을 바꿨다면 그 경로의 필요한 통합 검증을 추가한다.
3. 앱 로직은 변경 분기·경계·오류를 확인하는 관련 unit class/method를 선택한다. UI는 변경 상태의 렌더링과 핵심 사용자 동작을 확인하는 최소 selector를 선택한다. 공통 smoke는 앱 진입·전역 탐색 등 공통 동작에 영향이 있을 때만 추가한다. 모든 feature 수정에 smoke 합집합을 강제하지 않는다.
4. 공유 코드도 소비자를 확인해 영향받는 대표 흐름과 플랫폼의 selector를 선택한다. 영향이 불명확하면 호출부를 더 조사하고 남은 위험을 기록한다. 이를 이유로 자동 full 실행하지 않는다. 필요한 핵심 검사가 없으면 작성하거나 허용된 재현 검증으로 보완한다. 전체 회귀는 사용자가 명시적으로 요청했을 때만 로컬에서 실행한다.
5. 최종 상태에서 정한 핵심 검증이 모두 통과하면 해당 범위의 게이트를 충족한다. **요청하지 않은 full 회귀를 미완료 필수 게이트로 남겨 브랜치 완료/Ship를 막지 않는다.** 판정기의 `full`은 영향 조사 경고이지 전체 실행 명령이 아니다. targeted 결과를 전체 통과로 표현하지 않는다. 필수 핵심 검사의 실패·미실행과 사용자 요청 full의 미실행은 계속 미완료다.
6. 앱 테스트가 같은 target/configuration의 컴파일까지 성공했다면 그 target의 별도 build-only를 반복하지 않는다. 테스트가 빌드하지 않은 영향 target만 추가 빌드한다. `.xcstrings`·프로젝트 후처리 등 관련 검사는 유지한다. Work → UI → Review → Resolve → Ship에서도 이미 유효한 검증은 재사용하고 이후 변경에 영향받는 항목만 갱신한다.

| 자원 | 로컬 기본값과 종료 조건 |
|------|--------------------------|
| 무거운 실행 | 한 worktree에 build/unit/UI/capture 중 **하나만** 진행. agent도 같은 예산을 공유한다. 읽기/문서 작업만 병행한다. 다른 worktree와의 simulator 병행은 아래 사용자 명시 예외만 허용한다. |
| 컴파일·테스트 병렬성 | 표준 build-ios/build-target/unit/iOS UI/watch UI 실행기의 기본 `-jobs 2`, index store `NO`. 커밋 훅의 target compile도 포함한다. 로컬 unit 병렬 테스트는 `NO`, UI도 기존 `NO` 유지. `DAILVE_XCODEBUILD_JOBS=1`로 더 줄일 수 있다. 증가는 실행 전 근거와 함께 명시한다. 이 값은 Xcode build job 제한이며 전체 host 프로세스 수·CPU 사용률 상한은 아니다. |
| 시간 | build는 900초, targeted unit/UI는 1200초를 시작 예산으로 정한다. build/unit는 `scripts/lib/command-deadline.py --seconds <예산> -- <표준 실행기 ...>` 또는 같은 timeout의 pipeline wrapper로 소유 프로세스를 제한한다. 커밋 훅의 build도 같은 watchdog을 사용하며 `DUNE_BUILD_WALL_TIMEOUT` 기본값은 900초다. UI는 `DUNE_UI_TEST_WALL_TIMEOUT=1200`을 해당 명령에 전달한다. 예상 범위상 부족하면 실행 **전** 근거와 예산을 조정하고 실행 중 무기한 연장하지 않는다. |
| 기기·캡처 | 영향받는 기기/상태만 순차 사용. 테스트 attachment와 필요한 디자인맵 PNG를 한 실행에서 수집할 수 있으면 재활용한다. 검증 뒤 이번 작업이 boot한 소유 기기만, 활성 runner가 없음을 확인한 뒤 shutdown한다. 사용자/다른 worktree 기기와 공용 service는 건드리지 않는다. |
| 캐시·대기 | worktree 전용 DerivedData를 증분 재사용한다. 원인 근거 없는 clean/캐시 삭제/시뮬레이터 재생성/전체 rebuild는 금지한다. 기존 session에서 대기하고 완료/timeout 뒤 소유 자식 정리를 확인한다. `killall`, 광범위 `pkill`, 전역 CoreSimulator 재시작으로 해결하지 않는다. |

스킬별 적용 지점은 다음과 같다. 각 스킬의 기능·산출물과 검증 범위를 분리하며, 스킬을 읽었다는 이유만으로 전체 파이프라인을 새로 시작하지 않는다.

| 스킬 | 적용 |
|------|------|
| run | Phase 1에서 핵심 검증 계약을 정하고 Work/2.5/Resolve/Ship가 같은 증거를 공유한다. phase마다 전체 테스트·빌드를 반복하지 않는다. |
| plan, brainstorm | 영향·핵심 위험·선택 검사·예산을 계획한다. 계획 작성 자체에 앱 실행을 요구하지 않는다. |
| work, debug | 관련 unit → 필요한 UI 순서로 확인한다. 실패는 해당 경로부터 수정·검증하고 최종 영향 범위만 확인한다. |
| testing-patterns, ui-testing, xcode-project | 원본의 전체 target/raw xcodebuild 예시는 그대로 실행하지 않고 표준 실행기와 정확한 selector로 변환한다. |
| review, triage | 검증 receipt와 diff를 읽어 검토한다. 관점마다 실행기를 띄우지 않는다. 부족한 검사는 한 담당자가 한 번 수행한다. |
| ship | 최신 diff·검증·미해결 finding을 확인한다. Ship 진입 자체는 전체 테스트/재빌드 사유가 아니다. |
| compound, retrospective, changelog, onboard, cleanup | 문서·정리 작업에 앱 테스트를 추가하지 않는다. 실제 실행 도구를 변경한 경우에만 해당 계약을 검증한다. |
| code-style, copy-voice, design-system, agent-architecture | 변경한 코드/문구/디자인/지침의 영향 범위를 따른다. 화면 변경의 실제 디자인맵 의무는 유지하되 무관한 화면·기기는 실행하지 않는다. |

### 재시도와 범위 확장 제한

사용자가 요청한 무의미한 재시도 방지 규칙이다. Claude 원본의 반복 실행 지시보다 이 Codex 실행 한도를 우선한다.

- 실행 전 현재 변경에 필요한 검증인지 확인한다. 문서/도구 작업에서 관성적으로 앱 빌드·전체 UI·smoke를 실행하지 않는다. 필요한 최소 검증을 통과했으면 새 변경/실패 근거 없이 범위를 넓히지 않는다.
- 코드 변경의 영향 범위에 있는 테스트만 실행한다. 그 테스트가 실패하면 원인을 수정한 뒤 실패한 테스트를 다시 실행해 확인한다. 전체 테스트는 사용자가 요청한 경우에만 실행한다. 실패 보고만 하고 멈추거나, 영향 범위 밖의 suite를 자동으로 실행하거나, targeted 통과를 전체 통과로 보고하지 않는다.
- 실패하면 `작업 / 실패 지점·원인 / 새로 확인된 변화 / 재시도 횟수 / 다음 조치`를 짧게 기록한다. 명령 표기, 로그 경로, 모델, phase 또는 대화 turn이 바뀌어도 같은 원인에는 같은 횟수를 적용한다.
- 같은 원인에 대한 자동 재시도는 **최대 1회**다. 원인에 대응한 코드 수정 또는 실패한 의존성의 정상 동작 확인이 먼저 있어야 한다. 시간 경과, 일시적인 부하 하락, 단순 목록 조회 성공, 막연한 기대만으로 재실행하지 않는다. 새 실패 원인으로 횟수를 초기화하려면 기존 원인이 해소됐다는 증거가 있어야 한다.
- 재시도에서도 같은 원인이 남으면 해당 실행 경로를 중단하고 원인·미검증 범위·정확한 재개 조건을 기록한다. 독립적으로 가능한 작업은 계속한다. 환경 실패를 코드 실패/테스트 통과로 보고하지 않으며, 필요한 검증이 막힌 상태로 게이트를 통과시키지 않는다.
- 진행 중인 실행은 복제 실행하지 않는다. 해당 도구의 대기 기능을 사용하고 새 출력이 없으면 반복 로그 읽기·프로세스 조회를 하지 않는다. 상태 조회가 필요할 때는 30~60초 간격으로 하며, 같은 상태가 2회 이어지면 정한 timeout/완료 이벤트를 기다린다. 사용자에게 필요한 진행 안내는 별도로 유지한다.
- 긴 실행에서 `clock → sleep → tail/ps → write_stdin`을 별도 모델 호출로 반복하지 않는다. 기존 실행 session의 대기 기능을 사용하고 짧은 yield 뒤 무출력 재호출을 쌓지 않는다. 사용자 진행 안내는 60초 이내로 유지하되, 안내를 위해 새 진단 명령을 만들지는 않는다.
- 사용자에게 실행 비용과 종료 조건을 먼저 알린다. 단순 기능 수정에서 테스트·캡처·리뷰를 완료 조건 없이 계속 추가하지 않는다. 검증에 실패하면 실패 지점과 남은 범위를 기록하고, 동일 원인에서 새 수정 없이 재실행하지 않는다.
- 무관한 기존 실패는 이번 작업의 diff에 원인이 있는지 먼저 확인한다. 관계가 없으면 별도 이슈로 기록하고 현재 작업의 검증 범위를 다시 확정한다. 완료 조건을 맞추려고 관계없는 앱/테스트를 수정하거나 검증 중 실행기 파일을 수정하지 않는다.
- 이미 유효한 검증/리뷰가 있으면 같은 내용을 다시 실행하지 않는다. 수정 후 재리뷰는 바뀐 부분과 영향을 받는 관점만 수행하고 기존 결과의 유효 범위를 함께 기록한다. 실행만을 위한 agent 생성, 변화 없는 agent 재호출, 해결 근거 없는 모델 상향을 하지 않는다.

### /run

- Phase tracking은 사용 가능한 계획 도구 또는 phase 상태 기록으로 관리한다.
- Start/Complete markers는 `commentary` 채널에 출력한다.
- Proof Ledger는 별도 파일이 아니라 각 phase 완료 메시지와 최종 summary에 집계한다.
- review/quality 단계는 공통 위임 정책과 agent-map을 따른다. 각 필수 관점의 판단/결과는 유지한다.
- Work의 테스트와 Quality 결과를 뒤 phase에서 다시 사용할 때는 `.codex/token-efficiency.md`의 증거 일치 조건을 확인한다. 유효한 동일 검증은 재실행 대신 evidence 경로를 기록한다. 이는 phase 생략이 아니며, 변경/누락된 검증은 실행한다.
- `/run` 안의 `/work`는 구현/QC까지만 담당하고 Compound/Ship는 parent가 한 번 수행한다. UI 최종 범위는 아래 변경 범위 기반 UI 게이트로 결정한다. 사용자가 요청한 full을 smoke로 대체하지 않는다.
- `/run` parent가 검증/리뷰 관점별 실행 담당을 한 번 배정한다. Work에서 완료한 전문 검토는 Phase 3.5에서 증거·대상·환경의 유효성을 확인해 재사용하고, 이후 변경으로 영향을 받는 관점만 다시 수행한다. standalone `/work`에도 동일한 핵심 검증·점유 예산을 적용한다.
- UI 실행권·환경이 막혀도 독립적인 read-only 코드 검토, 로그 분석, 문서 준비까지 전부 중단하지 않는다. UI 게이트는 미완료로 유지하고 선행 검토의 대상 diff·결과를 보존한다. 실행 환경이 복구되면 미검증 selector와 이후 변경분만 이어서 확인하며, 선행 검토를 UI 통과나 Ship 허가로 해석하지 않는다.
- phase 상태·증거·문서 확인 이력은 `scripts/codex-pipeline.py`로 기록/검사한다(사용법은 `.codex/token-efficiency.md`). 기록의 존재만으로 완료를 선언하지 않는다. 원문과 adapter를 이번 실행에 적용한 판단은 parent가 유지하며, 문서 hash 확인은 원문 읽기/이해의 대체가 아니다. tool의 compact report를 바탕으로 필수 시작/완료 안내와 최종 증빙을 집계하고 같은 로그/절차를 반복 서술하지 않는다.
- Ship 단계는 auth/network/remote 조건이 충족될 때만 실제 `gh` 작업을 수행한다. 막히면 manual recovery를 출력한다.

#### 변경 범위 기반 UI 게이트

사용자가 승인한 UI 검증 비용 개선에 따른 Codex 전용 실행 예외다. Claude 원본 S11 및 Phase 2.5의 무조건 full 요구를 다음 범위 판정으로 대체한다. Phase 자체나 결과 보고는 생략하지 않는다. `.claude/**` 원본과 Claude 실행 정책은 유지한다.

모든 스킬에 위 핵심 검증 정책을 적용한다. 아래 판정이 `full`이어도 전체 테스트는 사용자가 명시적으로 요청한 경우에만 로컬 실행한다. 요청이 없으면 영향 조사 후 필요한 targeted selector를 확정하고 그 통과로 게이트를 판단한다. 전체 회귀 미실행은 검증 범위의 한계이며 별도 실패 게이트가 아니다.

1. Phase 1에서 `python3 scripts/plan-ui-tests.py --base main`으로 계획하고, Phase 2.5 및 Resolve 후 최종 변경 상태에서 다시 실행한다. 출력 JSON은 로그 디렉터리에 저장한다. base가 다른 작업은 실제 PR base를 지정한다. merge-base부터 tracked 현재 상태, untracked 파일, 삭제/rename 양쪽 경로가 포함된다. Git 실패를 변경 없음으로 취급하지 않는다.
2. 파일별 이유, 플랫폼별 `skip/targeted/full`, 명령 argv를 검토한다. 판정기는 의존성 분석/테스트 실행/통과 인증기가 아니다. 변경 symbol의 다른 feature 소비자를 `rg` 또는 심볼 도구로 확인하고 필요한 selector를 보완한다. 출력 argv를 무조건 실행하지 않는다. 새 화면/동작의 테스트가 없으면 작성한다. View 파일명만으로 판단하지 않는다.
3. 기본 범위:
   - 문서/지침 Markdown만 변경: UI `skipped`, 경로와 근거 기록. 앱 리소스 안의 Markdown은 면제하지 않는다.
   - unit test Swift 파일만 변경: 관련 unit 검증, UI `skipped`.
   - UI 게이트 판정기/CLI 선택/로그 검증 및 해당 계약 테스트만 변경: Python 계약 테스트, shell 구문, dry-run argv와 diff 리뷰로 검증하고 앱 UI는 `skipped`. 도구 수정 자체를 이유로 전체 UI나 공통 smoke를 실행하지 않는다. 판정기의 정확한 tooling 경로 목록은 검증 의무를 표시하며, 실행/설치/seed/기기 선택/CI 실행 환경 변경이 포함되면 영향을 받는 통합 검증으로 상향한다.
   - Codex snapshot/receipt/pipeline/parity 도구와 정확히 매핑된 계약 테스트만 변경: 해당 Python 계약·parity 검증과 diff 리뷰를 수행한다. watch 실행기의 로그/결과 검증만 변경한 경우도 tooling 검증 대상이다. 파일 경로 면제는 잠정 분류이며 실행 명령·설치·seed·기기·CI 변경이 없는지 확인해야 한다. 미매핑 script는 실제 동작·호출부를 조사해 필요한 계약/통합 검증을 정한다.
   - 매핑된 feature 화면/ViewModel: 관련 UI class/method를 선택한다. 공통 탐색에 영향이 있을 때만 `--smoke`를 합친다. CLI는 디렉터리명이 아닌 실제 class/method selector를 받는다.
   - App/Domain/Data/Shared, 내비게이션/전역 테마/저장/프로젝트 설정, 공유 test helper 또는 미매핑 변경: `full` 경고를 바탕으로 소비자와 플랫폼을 조사해 핵심 selector를 정한다. watch·widget·visionOS 등 실제 영향 target만 별도 검증한다. 공유 폴더라는 이유만으로 모든 플랫폼 전체 회귀를 실행하지 않는다.
   - 화면 영향이 없는 순수 계산 로직: 호출부 분석과 관련 단위 테스트 통과를 기록하고 UI `skipped`로 판단할 수 있다. 근거가 부족하면 관련 소비자의 UI selector를 보완한다.
   - CI/nightly의 기존 전체 회귀는 유지한다. 로컬 릴리스 점검도 사용자 요청 범위를 따른다. HealthKit 권한 등 Simulator로 검증할 수 없는 필수 동작은 별도 실제 기기 검증으로 기록한다.
4. `--smoke`만 실행해서 변경 기능 검증을 대체하지 않는다. 테스트 선택이 새 동작 커버리지를 증명하지 않는다. 제스처/차트의 seeded lifecycle, 번역/Dynamic Type/iPad/watch 등 해당 변경의 기존 검증 의무를 유지한다.
5. 완료 증빙: 변경 경로/판정 이유, 실제 명령·plan·기기, 결과 로그, 수행/skip 수, 관련 suite 실행 여부를 기록한다. UI가 필요한데 미실행/0개/unknown count/필수 suite 누락/실패면 게이트 실패다. 정당한 UI 면제는 `skipped`로 기록하고 “UI 통과/레이아웃 확인 완료”라고 보고하지 않는다.
6. 수정 중에는 실패 관련 테스트부터 확인한다. 최종 변경 상태에 필요한 범위가 모두 통과해야 Review/Ship로 진행한다. 동일 성공 증거 재사용은 `.codex/token-efficiency.md` 조건을 따르며 targeted 성공을 full 증거로 승격하지 않는다.
7. 자동 판정 범위를 축소한 경우 근거와 대체 검증을 Proof Ledger에 남긴다. 인프라 변경은 실행기 fixture/구문/parity 검증도 수행한다. 다른 게이트에도 위 핵심 검증·중복 빌드 방지 정책을 동일하게 적용한다.
   - 앱 소스·프로젝트·UI test body·seed/helper가 동일한 CLI 선택 변경은 fixture와 dry-run 검증 결과 및 앱 관련 diff 없음으로 증빙한다. 검증 도중 발견한 무관한 기존 UI 실패를 수정하느라 작업 범위를 확장하지 않는다. 중단한 UI 실행은 통과 증거가 아니며 이번 도구 작업의 완료 조건으로 삼지 않는다.

### 실제 화면 디자인맵 동기화

Codex가 iOS·iPadOS·Duo·watchOS의 보이는 화면 배치, 글자, 상태, 내비게이션을 바꾸면 같은 작업에서 `docs/design/phone-design-map/actual/index.html`의 영향받는 화면을 갱신한다. `docs/design/phone-design-map/screen-inventory.md`와 Watch 상태표에서 화면 ID를 찾고, 해당 기기·상태의 UI 테스트를 시뮬레이터에서 실행해 새 PNG를 수집한다. `docs/design/phone-design-map/README.md`의 「화면 수정 시 갱신」 절차를 따른다. 영향 범위만 캡처하며, 전체 맵 재캡처는 사용자가 명시적으로 요청한 경우에만 한다.

- 실제 앱 캡처와 캡처 출처를 갱신하고 갤러리·보드·통합 포털을 재생성한 뒤 화면의 잘림, 겹침, 글자 크기를 확인한다. UI 테스트 통과만으로 디자인맵 갱신을 완료했다고 보고하지 않는다.
- 화면 영향이 없다고 판단한 변경은 호출부와 근거를 기록한다. 캡처가 막히거나 상태에 진입할 수 없으면 기존 이미지를 새 버전의 증거로 제시하지 않고 영향받는 화면 ID, 미갱신 기기, 원인과 재개 조건을 보고한다.
- 이 동기화는 위 UI 테스트 범위 게이트에 추가되는 산출물 검증이다. 문서/도구만 수정해 앱 화면이 바뀌지 않은 작업에는 캡처를 요구하지 않는다.

### /plan

- 계획서는 항상 `docs/plans/YYYY-MM-DD-{topic-slug}.md` 에 실제 생성한다.
- `planner` agent는 preferred role이지 필수 spawn이 아니다.
- parent skill이 `/run` 인 경우에는 별도 사용자 승인 대기 없이 진행한다.

### /work

- detached HEAD 또는 `main` 에서는 구현 커밋 전에 `codex/` prefix 작업 브랜치를 만든다.
- baseline dirty 파일은 자동 커밋 범위에서 제외한다.
- quality agents는 기본적으로 findings를 내고, 실제 수정은 같은 Work phase의 구현 단위 또는 Resolve phase로 넘긴다.
- standalone 실행도 위 핵심 검증 계약을 사용한다. build/test를 같은 커밋·phase에서 중복 실행하지 않는다.

### /debug

- 재현은 실패한 동작·selector 하나에서 시작하고 원인 수정 뒤 해당 검사와 영향받는 회귀만 실행한다. 환경 장애는 앱 코드 실패와 분리한다. 화면 잠금 추정으로 재현을 생략하지 않고 [UI 실행 환경 진단](ui-execution.md)을 따른다.

### /testing-patterns

- 변경된 분기·경계·오류의 테스트 작성 의무는 유지하되 실행은 관련 class/method만 선택한다. `scripts/test-unit.sh --ios-only --only-testing DUNETests/<실제Suite>`처럼 target을 한정한다. Watch 영향이 있을 때만 해당 Watch selector를 추가한다. selector 없는 unit 실행은 전체 요청 때만 사용한다.

### /xcode-project

- 생성·빌드는 기존 표준 실행기/후처리를 유지한다. 소스나 프로젝트 변경이 없으면 재생성·빌드하지 않는다. 로컬 job 예산은 `scripts/lib/xcodebuild-resources.sh`를 따르며, standalone 실행에도 동일한 deadline을 씌운다. 캐시 불일치 증거 없이 clean을 선행하지 않는다.

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

- `scripts/lib/simulator-worktree.sh`는 clone 이름에 워크트리 부모 디렉터리와 경로 해시를 넣는다(예: `iPhone 17-wt-Health-8d4b-...`). clone 전 기기 목록을 기준선으로 확인하고, 생성 성공 후 `.codex-checks/worktree-simulators.json`에 신규 UDID, 정확한 이름, 워크트리 절대 경로와 기준선 검증 여부를 기록한다. clone 실패로 fallback한 원본과 기존 기기는 기록하지 않는다.
- Step 1에서 기록 파일과 `simulator-orphans` 복구 표식(`.codex-checks` 및 임시 디렉터리 fallback)을 확인한다. 등록과 롤백이 모두 실패한 기기는 복구 표식으로 남으며 자동 삭제하지 않는다. 생성 기록이 없는 기기는 이름이 비슷해도 삭제하지 않는다. Step 3의 **원격 머지 성공을 확인한 직후**, Step 4의 checkout 및 worktree 제거 전에 `python3 scripts/lib/simulator-test-lock.py "$PWD" -- bash scripts/lib/simulator-worktree.sh --cleanup-current`를 실행해 진행 중인 테스트와 직렬화한다. `/run`에서 호출된 Ship에도 동일하게 적용한다. 머지 실패 시에는 기기를 유지한다.
- 정리 명령은 기록의 worktree/UDID/이름을 현재 `simctl` 목록과 대조하고 종료·삭제·삭제 확인을 수행한다. 복구 표식이 있는 기기는 수동 확인 대상으로 보고하고 삭제하지 않는다. 실패하거나 소유가 불명확한 기기는 보존하며 나머지는 계속 처리한다. `--cleanup-all`과 `simctl delete all`은 Ship에서 사용하지 않는다. 기록을 읽지 못하거나 미정리 기기·복구 표식이 남으면 Step 4 이후 로컬 정리를 중단하여 worktree의 기록과 복구 경로를 보존한다. 원격 머지는 완료됐고 로컬 정리는 미완료임을 보고한다.
- 최종 결과에 삭제한 기기 수와 남은 기기/사유를 포함한다. 목록 조회나 삭제 실패를 정리 성공으로 보고하지 않는다.

#### Ship 외부 DerivedData 정리

- 원격 머지 성공 후 **제거가 확정된 linked worktree만** 아래 `/cleanup`의 외부 DerivedData 정리 대상으로 삼는다. primary checkout에서 브랜치만 정리하는 Ship은 이 외부 캐시 정리를 건너뛴다. `/run`과 `/work`에서 호출하는 Ship에도 동일하게 적용하며, 머지 실패 시 캐시를 유지한다.
- Ship에 이미 승인된 정리 범위라면 별도 승인을 반복하지 않는다. 삭제 실패·잠금 충돌 시 worktree를 보존하고 원격 머지 완료/로컬 정리 미완료를 구분해 보고한다.

#### Ship linked worktree의 로컬 정리 순서

- Step 1에서 `git worktree list --porcelain`과 `git rev-parse --git-dir --git-common-dir`로 현재 checkout이 linked worktree인지 판별하고 정확한 worktree 경로·브랜치·primary checkout을 기록한다. main 체크아웃이 다른 위치에 있으면 실제 main checkout을 사용한다. primary checkout에서 실행하는 Ship은 원본 Step 4를 유지한다.
- linked worktree에서는 원본 Step 4의 `git checkout main`을 실행하지 않는다. **원격 머지를 확인한 뒤**, main checkout이 `main`이고 변경사항이 없음을 확인하고 그 경로에서 `git pull --ff-only`로 먼저 갱신한다. 이 확인이나 갱신에 실패하면 linked worktree와 캐시를 보존하고 로컬 정리 미완료로 보고한다.
- main 갱신 후 현재 linked worktree에 미커밋·신규 파일이 없고 해당 PR의 머지 커밋이 main에 포함됐는지 확인한다. 이어서 위 소유 simulator 정리와 외부 DerivedData 정리를 실행한다. 이 linked 흐름에서는 이 순서가 기존의 원격 머지 직후 simulator 정리 시점보다 우선한다. 진행 중인 빌드·테스트, 복구 표식, 정리 실패가 있으면 worktree 제거를 중단한다.
- 모두 성공한 뒤 **main checkout 경로에서** `git worktree remove "<대상 worktree>"`와 `git branch -d "<대상 branch>"`를 실행한다. force는 사용하지 않는다. 원격 브랜치 삭제 성공도 확인한다. 이후 Step 5 아티팩트 정리와 Step 6 프로젝트 재생성은 갱신된 main checkout에서 실행한다. primary checkout의 `.claude/**`나 기존 변경사항은 자동 커밋하지 않는다.

### /cleanup

- 원본의 PR 머지 확인·worktree 보호·삭제 승인 규칙을 유지한다. **삭제가 확정된 worktree만** 외부 DerivedData 정리 대상으로 삼고, 단순 로컬 브랜치 삭제·보호됨·보류 대상의 캐시는 건드리지 않는다.
- 삭제 후보를 제시할 때 `python3 scripts/cleanup-worktree-deriveddata.py --worktree "<대상 worktree 절대 경로>"`로 dry run하여 캐시 경로와 소유 프로젝트를 함께 표시한다. 기본 탐색 위치는 `~/Library/Developer/Xcode/DerivedData`이며, 별도 외부 캐시 부모가 확인되면 `--derived-data-root "<부모 경로>"`를 반복 전달한다. 이 옵션은 기본 위치를 대체하므로 기본 위치도 필요하면 함께 명시한다. 디스크 전체나 이름 패턴으로 탐색하지 않는다.
- 사용자 지정 부모는 모두 존재하는 디렉터리여야 하며 서로 포함 관계인 경로는 거부한다. 오타나 중첩 경로가 있으면 캐시를 삭제하지 않고 실패한다. 기본 Xcode 캐시 위치가 아직 없는 경우만 정상 no-op으로 처리한다.
- 워크트리 소유권은 캐시 직속 `info.plist`의 절대 `WorkspacePath`를 정규화한 경로로 판정한다. 대상은 기존 linked worktree 루트만 허용하며 primary checkout은 거부한다. 동일 이름의 다른 worktree·main·공용 캐시·소유 미확인·손상된 메타데이터·symlink 캐시와 중첩 checkout은 보존한다. 외부 사용자 지정 경로도 동일 기준을 적용하며 메타데이터가 없으면 추정 삭제하지 않는다. 여러 worktree가 공유한다고 알려진 사용자 지정 경로는 전달하지 않는다.
- 승인된 worktree를 제거하기 **전**, 해당 worktree의 Xcode 빌드가 실행 중이지 않음을 확인하고 다음 명령을 실행한다. `<저장소>`는 스크립트가 존재하는 checkout의 절대 경로다. dry run과 동일한 외부 부모 옵션을 전달한다. 잠금은 대상 worktree 기준이며 충돌 시 기다리지 않고 정리를 보류한다.

  ```bash
  DUNE_SIM_TEST_LOCK_WAIT_SECONDS=0 python3 "<저장소>/scripts/lib/simulator-test-lock.py" "<대상 worktree>" -- python3 "<저장소>/scripts/cleanup-worktree-deriveddata.py" --worktree "<대상 worktree>" --apply
  ```

- 스크립트는 삭제 직전 소유권과 디렉터리 identity를 다시 확인한다. 캐시를 같은 부모의 전용 임시 디렉터리로 원자적으로 이동하고 다시 검증한 뒤 삭제하여, 원래 경로에 새로 생성된 캐시를 보호한다. 이동 후 검증/삭제가 실패하면 잔여 캐시를 보존하고 `Recovery required`에 실제 보존 경로와 원래 경로를 출력한다. 복구 경로는 자동 재삭제하지 않는다. 캐시 삭제 후 빈 임시 디렉터리만 제거하지 못한 경우에는 삭제 건수를 유지하면서 남은 경로와 실패를 별도로 보고한다. 스캔/삭제 실패는 성공으로 숨기지 않고 해당 worktree 제거를 중단한다. 보존한 캐시는 사유와 함께 보고한다. 캐시 삭제에 성공한 뒤 원본의 `git worktree remove`와 브랜치 정리를 진행한다. worktree가 이미 없어졌다면 소유 확인을 생략하거나 이름으로 삭제하지 않는다.
- 이 절차는 Codex의 `/cleanup`·`/ship` 실행 지침이다. 수동 `git worktree remove`, Codex 앱 자체 삭제, pre-commit에서 자동 실행되는 hook은 아니다. `.claude/**` 원본과 pre-commit의 캐시 보존 동작은 변경하지 않는다.

### /copy-voice

- 원본: `.claude/skills/copy-voice/SKILL.md`. 사용자 대면 문구 작성·수정·검토 시 [UX Writing 보완 규칙](ux-writing.md)을 함께 읽는다.
- `.codex/ux-writing.md`는 제목·본문의 의미 중복 방지, 명확한 행동명, 사실과 추정의 구분, Watch 문구 길이와 원본 제한의 명시적 대체 기준을 관리한다. 본문 규칙을 이 문서에 복제하지 않는다.
- 공식 근거 확인일은 2026-10-28이며 출처의 발행·개정일과 구분한다. 원본 `.claude/**`, 기존 localization·실제 화면 검증 범위는 변경하지 않는다.

### /ui-testing

- **입력 UI의 키보드 사전 조건**: 폼·텍스트 입력·키보드가 포함된 Simulator 검사는 현재 worktree 전용 기기에서 하드웨어 키보드 연결을 해제하고 소프트웨어 키보드 표시 상태를 확인한다. 메뉴 탭 뒤 폼이 열리지 않거나 입력 필드·키보드 조회가 실패하면 앱/테스트 코드를 수정하기 전에 이 설정을 먼저 확인한다. 확인 절차와 사용자 확인 근거는 [소프트웨어 키보드 확인](ui-execution.md#소프트웨어-키보드-확인)을 따른다. 키보드 활성화 확인과 해당 UI 검사 통과는 별도로 기록한다.
- 환경 실패·화면 잠금·실행권 대기가 발생하면 `.codex/ui-execution.md`를 읽고 단계를 분류한다. **Mac 화면 잠금만으로 불가 판정·사용자 잠금 해제 요청·대기 전환하지 않는다.** 기존 잠금 상태 성공 근거를 읽고 같은 예산 안에서 표준 XCTest·guest 캡처·필요한 CLI/readback 경로를 확인한다. 저장소 simulator 실행 잠금과 Mac 화면 잠금은 다르다. 실행기 `<log>.host.json`은 진단 자료이며 UI 통과 증거가 아니다.
- `agent: ui-test-expert`는 agent-map의 실제 모델 배정을 사용한다. 테스트 실행 자체에는 agent가 필요 없으며, 여러 화면 조작·증거 수집은 위 **실행 검증 수집 위임**의 조건과 역할 제한을 따른다. 테스트 설계·구현과 시각적 품질 판단은 실행 수집 모드로 내리지 않는다.
- Unit/UI/watch 테스트는 기존 `scripts/test-unit.sh`, `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`를 표준 경로로 사용한다. 기본 파일 로그/요약을 유지하고 필요한 때만 streaming한다.
- **UI 실행 점유 제한**: Codex 로컬 UI 테스트는 raw `xcodebuild test` 대신 표준 UI 실행기를 사용한다. 실행기에는 시뮬레이터 잠금 대기 60초, 로그 무갱신 15분, 전체 실행 deadline이 있다. 실행기 자체의 fallback은 focused/smoke 30분·full 3시간이지만 Codex는 위 점유 예산에 따라 targeted 실행에 `DUNE_UI_TEST_WALL_TIMEOUT=1200`을 전달한다. 더 긴 검증은 범위와 이유를 정한 뒤 `DUNE_UI_TEST_WALL_TIMEOUT`과 필요한 `DUNE_UI_TEST_IDLE_TIMEOUT`을 실행 전에 명시한다. deadline 124, 잠금 대기 실패, 테스트 결과 정체는 실패 증거다. 별도 PID를 임의 종료하거나 같은 명령을 이름만 바꿔 재시도하지 않는다.
- **전용 시뮬레이터 사용**: 사용자가 특정 기기를 직접 지정한 경우 외에는 현재 worktree 소유로 등록된 clone을 단독 사용한다. iPhone·iPad·Duo·Watch의 UI 테스트, 앱 설치·초기화, 수동 캡처, 자세·회전 전환에 모두 적용한다. 명시적 UDID를 넘기기 전에도 `.codex-checks/worktree-simulators.json`의 worktree·UDID·이름과 실제 기기를 대조한다. `booted` 선택이나 공용 원본·다른 worktree 기기로의 fallback은 사용하지 않는다. 전용 기기 조회·생성·소유권 확인이 실패하면 해당 실행을 중단하고 원인과 재개 조건을 기록한다. 전용 기기도 저장소 잠금과 실행 deadline을 유지한다.
- UI 명령 시작 전 변경 범위와 정확한 selector/기기/plan을 정한다. 일반 기능 수정은 영향받는 단일 기기와 테스트부터 실행하고, 추가 기기·full·전체 디자인맵은 실제 영향 또는 명시적 사용자 요청이 있을 때만 연다. 한 저장소에서 한 번에 한 UI runner만 진행하고 테스트 완료 전에 새 runner를 만들지 않는다.
- **사용자가 별도 기기로 병행 검증을 요청한 경우**: 연결된 다른 worktree의 전용 기기·DerivedData·로그가 모두 격리됐고 현재 worktree에 기존 실행이 없음을 확인한 뒤 `DUNE_SIM_TEST_LOCK_SCOPE=worktree`를 명시할 수 있다. 이 경우에만 저장소 단위 직렬화의 예외이며, 현재 worktree 잠금과 실행 deadline은 유지한다. 업데이트 전 runner는 worktree 잠금을 갖고 있지 않으므로 프로세스의 작업 경로·대상 UDID도 확인한다. 공용 기기 fallback, 다른 worktree 기기 조작, 공유 build/result 경로, 전역 Simulator/GUI 조작에는 이 예외를 적용하지 않는다. 환경 변수는 해당 명령에만 전달하고 기본값으로 저장하지 않는다.
- iPhone 검증 후 watchOS 검증으로 넘어갈 때 iPhone runner 종료와 결과 receipt를 먼저 확인한다. watch runner는 잠금을 얻은 뒤 이 worktree가 소유한 동일 이름의 Watch clone을 삭제 확인하고 새로 생성한다. 삭제·소유권 확인에 실패하면 Watch 검증을 시작하지 않는다. 공용 원본·다른 worktree 기기는 삭제하지 않는다.
- 실행기 계약 테스트도 같은 호스트에서는 순차 실행한다. 동시 fixture·시뮬레이터 조회가 대기 시간을 늘린 경우 실행을 중지하고 소유 자식이 정리됐는지 확인한 뒤 해당 실패만 다시 진단한다. 프로세스 수를 줄이기 위한 진단 중에 새 백그라운드 runner를 시작하지 않는다.
- `xcodebuild`의 개별 testcase allowance는 빌드, CoreSimulator 부팅, 테스트 발견, `.xcresult` 정리 시간을 제한하지 않는다. 실행기가 timeout이면 마지막 testcase·로그 상태를 분류하고, 앱 실패와 SDK/host 정체를 구분한다. 정상 종료와 정확한 selector 결과 receipt가 확인되기 전에는 통과로 보고하지 않는다.
- 개발 중과 최종 검증 모두 위 변경 범위 기반 UI 게이트를 적용한다. `/run` 밖에서도 동일하다. 동일 검증의 재사용 조건은 `.codex/token-efficiency.md`를 따른다.
- UI 변경에서는 `swift-ui-expert`, `apple-ux-expert`, `ui-test-expert` 3개 관점을 분리해 판단한다.
- UI 테스트 작성 요청이 아닌 단순 UI 리뷰에서는 `ui-test-expert`를 findings-only로 사용할 수 있다.
