# 테스트 실행과 검증 재사용

모델 배정은 `agent-map.md`, 공통 위임은 `skill-compat.md`를 따른다. 이 문서는 테스트/검증 단계에서만 읽는다.

## 실행과 출력

- 지침 크기 진단: `python3 scripts/codex-context.py inventory`. 본문 없이 파일 수·총 bytes·상위 10개만 출력한다. 필수 문서를 생략하는 도구가 아니며, bytes를 토큰 절감률로 환산하지 않는다.
- 리뷰 입력 수집: `python3 scripts/codex-context.py snapshot --base main`. 실제 PR base를 사용한다. 시스템 임시 디렉터리의 manifest와 branch/staged/unstaged patch를 공유하고 본문 전체를 채팅에 재출력하지 않는다. `check <디렉터리>`가 실패하면 기존 snapshot으로 리뷰 완료를 선언하지 않는다. untracked 내용은 manifest의 경로에서 별도로 읽는다. 더 이상 사용하지 않는 snapshot 디렉터리는 작업 종료 시 정리할 수 있다.

- 명령 실행/대기는 셸 도구에 맡긴다. 실행만을 위한 모델이나 별도 agent를 생성하지 않는다.
- 표준 실행기: `scripts/test-unit.sh`, `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`. 기본 파일 로그와 요약을 사용하고, 로그 전체를 `cat`하지 않는다. CI streaming 기본 동작은 유지한다.
- 정상 결과는 종료 상태·로그 경로·보고된 테스트 수만 확인한다. 실패 시 제한된 오류 요약 → 해당 로그 구간 → 관련 소스 순서로 읽는다. 요약에서 수를 알 수 없으면 unknown이며 0건 성공으로 간주하지 않는다.
- iOS/watch UI 실행은 `<log>.result.json`에 target, 실제 종료 코드, executed/passed/skipped/failed 수, 누락 selector, 실패 요약을 기록한다. 최초 오류와 최근의 서로 다른 오류를 제한된 길이로 보존한다. JSON의 `status`와 실행기 종료 상태를 함께 확인한다. unknown/0건/식별 가능한 passed case 없음/필수 selector 누락은 실패다. 이 결과는 명시한 선택 범위의 실행 증거이며 full 커버리지·시각적 레이아웃 인증은 아니다.
- 개발 중 `test-ui.sh --only-testing <target/class/method>` 또는 `--smoke`로 빠르게 확인할 수 있다. 둘을 함께 주면 명시적 선택과 smoke의 합집합을 실행한다. `/run`의 최종 범위는 `.codex/skill-compat.md`의 변경 범위 기반 UI 게이트를 적용하고, 그 외는 source skill이 요구하는 범위를 유지한다. full 판정을 smoke/targeted로 대신하지 않는다. 단위 테스트의 `--ios-only`/`--watch-only`는 실제 변경 범위와 최종 요구조건에 맞게 사용한다.
- 실패 분류, 최대 1회 조건부 재시도, polling/범위 확장 제한은 `skill-compat.md`의 **재시도와 범위 확장 제한**을 따른다. 실패 로그는 최초 원인과 변경된 부분만 읽고 같은 전체 로그를 다시 로드하지 않는다.
- 제스처/차트/레이아웃 관련 source 규칙의 seeded/mock 재현 의무는 유지한다. 요소 존재만으로 시각적 레이아웃 전체를 검증했다고 보고하지 않는다.

## 동일 검증 증거

`scripts/codex-check.py`는 명령을 실행하는 `run`과 성공 증거만 확인하는 `check`를 제공한다. 테스트를 자동으로 건너뛰지 않는다. 동일한 작업의 뒤 phase에서 이미 수행한 검증을 재사용할 때만 `check`를 명시적으로 호출한다.

```sh
python3 scripts/codex-check.py run parity --context 'adapter-check-v1' -- python3 scripts/check-codex-claude-parity.py
python3 scripts/codex-check.py check parity --context 'adapter-check-v1' -- python3 scripts/check-codex-claude-parity.py
```

- 이름, 명령 argv, context, worktree/HEAD, tracked 및 nonignored untracked 파일 내용이 일치하고 성공 로그가 남아 있어야 한다. 실패/중단/실행 중 변경/증거 누락이면 재사용하지 않는다.
- 기본 모드는 HEAD/index도 비교한다. Git revision/index에 의존하지 않는 순수 빌드/테스트임을 확인한 경우에만 run/check 모두 `--content-only`를 명시해 내용이 동일한 commit 후에도 재사용한다. Git 기반 버전 생성, 변경분 검사 등은 기본 모드를 유지한다. 모드가 다르면 재사용하지 않는다.
- context는 같은 phase 이름이 아니라 **실행 환경 식별자**다. Xcode 검증은 Xcode/SDK 버전, simulator UDID/runtime, scheme/test plan, locale, launch/seed 조건, 관련 환경 변수의 안전한 식별자를 포함한다. 비밀 값은 기록하지 않는다.
- ignored 파일, 외부 의존성, simulator/app 데이터, 환경 변수는 worktree fingerprint만으로 보장되지 않는다. 재사용 직전에 그대로인지 확인하고 context를 갱신한다. 확인 불가, flaky 테스트, 권한/상태 변경이면 `run`으로 다시 실행한다.
- helper는 gate 범위를 판단하지 않는다. smoke/관련 테스트 증거를 full suite로, iPhone 증거를 iPad/watch 증거로 사용하지 않는다. 실행 전후 파일 변경이 있으면 명령 자체가 성공해도 재사용 증거로 인정하지 않는다.
- `check` 실패는 테스트 실패와 구분한다. 현재 요구 범위로 `run`을 수행하고 새 결과로 판단한다. 로그 저장소 `.codex-checks/`는 로컬 전용이며 수동 삭제하면 증거가 무효화된다.
- compiler/test runner가 일부 테스트만 수행했는지, skip/0 tests/예상 suite 누락이 없는지도 확인한다. 종료 코드 0만으로 요구 커버리지 충족을 선언하지 않는다.

## Review / Quality 재사용

- 이전 리뷰의 base/대상 diff, 관점, 결과/미해결 findings를 기록한다. 수정 후에는 delta와 영향을 받는 관점만 재검토하고 나머지 완료 결과의 유효성을 확인한다. 검증 범위가 변하거나 공유 영향이 생긴 경우에만 필요한 관점을 확대한다. `/run`에도 동일하게 적용하며, source의 기계적인 전체 재리뷰 대신 `skill-compat.md`의 재시도 제한을 따른다.
- 자동 테스트 receipt는 사람/agent의 리뷰를 증명하지 않는다. 리뷰 결과가 없으면 각 필수 관점을 수행한다. PR의 통합/크래시 검증은 이전 findings와 이후 diff를 함께 확인한다.
- 단계별 출력에는 수행 또는 재사용 여부와 실제 증거 경로를 한 줄로 남긴다. parent와 child가 같은 검증을 중복 수행하지 않게 소유자를 지정한다.

## Pipeline 상태와 중복 실행 방지

여러 phase에서 같은 검증을 사용하는 작업은 `scripts/codex-pipeline.py`를 사용한다. 위 `codex-check.py`의 fingerprint/원자적 저장/hash 구현을 공유하며, 상태는 ignored `.codex-checks/pipeline/`에 저장한다. 검증 ID는 작업과 검증을 식별하는 고정 이름으로 정하고 phase 이름 변경으로 새 ID를 만들지 않는다.

```sh
python3 scripts/codex-pipeline.py run tooling-contracts --context python-local --scope tooling --content-only -- python3 -B -m unittest discover -s scripts/tests
python3 scripts/codex-pipeline.py check tooling-contracts --context python-local --scope tooling --content-only -- python3 -B -m unittest discover -s scripts/tests
python3 scripts/codex-pipeline.py phase Work passed --evidence tooling-contracts
python3 scripts/codex-pipeline.py doc remember .codex/skill-compat.md
python3 scripts/codex-pipeline.py doc check .codex/skill-compat.md
python3 scripts/codex-pipeline.py report
```

- `run`은 명령을 한 번 실행하고 파일 로그·짧은 결과를 반환한다. 기다리는 동안 원래 도구 session을 사용하며 별도 로그 polling을 하지 않는다. worktree lock으로 동시 실행을 거부한다. 이미 유효한 성공이 있으면 재실행도 거부하므로 `check`를 사용한다.
- `--timeout <초>`로 제한하고 timeout/interrupt를 성공과 구분한다. 자동 재시도는 하지 않는다. 실패 후 재실행에는 `--retry-cause`, `--remediation`, `--retry-evidence <worktree 내 파일>`과 내용 또는 context 변화가 필요하다. 스크립트가 원인 해소를 의미적으로 판단하지 않으므로 실행자가 근거를 확인한다. 같은 ID의 실패 이력을 phase/turn 전환으로 지우지 않는다.
- wrapper가 강제 종료되어 running이 남으면 실제 남은 프로세스를 확인한 뒤 `recover <ID> --reason <확인 근거>`로 interrupted 상태를 기록한다. 활성 lock이 있으면 복구도 거부한다. 이 명령은 알 수 없는 PID를 종료하지 않으며 성공 증거를 만들지 않는다.
- `phase <이름> passed --evidence <ID>`는 현재 유효한 성공 증거를 참조한다. scope와 환경이 해당 phase의 필수 범위를 충족하는지는 실행자가 확인한다. 여러 의무가 있으면 검증 항목별 phase 이름으로 기록하고 일부 성공을 전체 완료로 보고하지 않는다.
- 전문가 결과는 `phase <관점> passed --review-file <파일> --source agent --context <기준-diff> --scope <관점> --content-only`로 보존한다. 실제 검토 후 findings/미해결 항목이 있는 파일만 등록한다. 도구는 파일 무결성과 소스 최신성을 검사하며 내용의 승인 여부를 판단하지 않는다. open P1/P2가 있으면 passed로 등록하지 않는다.
- `phase <이름> skipped --reason <근거>`는 정당한 면제 기록에만 사용한다. `report`/`status`에서 stale 증거는 재사용 불가다. 외부 상태·ignored 파일은 context와 별도 확인이 필요하다.
- 문서를 실제 읽은 뒤 `doc remember`로 hash를 기록한다. `doc check`는 변경 유무만 확인하며 원문 이해를 증명하지 않는다. 내용이 컨텍스트에서 사라졌다면 다시 읽는다. 별도의 원문 복제본이나 자동 축약본을 source of truth로 만들지 않는다.

## 절감 효과 확인

- 대표 사례는 단순 테스트 추가, UI 테스트 실패 수정, 일반 기능 구현으로 나눈다. 기존 작업의 기록을 baseline으로 사용하며 비용 측정만을 위해 전체 파이프라인을 반복하지 않는다.
- 작업별 모델/추론, 입력·캐시·출력 토큰(도구가 제공할 때), 재시도/상향 횟수, 명령 실행/재사용 횟수, 테스트 결과와 발견된 오류를 기록한다. 제공되지 않는 지표는 unknown으로 남긴다.
- 토큰 수, API 비용, Codex 계정 사용 한도는 별도 지표다. 문자/로그 줄 수 감소를 토큰 또는 계정 사용량 절감률로 환산하지 않는다. 계정 사용량은 다른 작업의 영향을 받는다.
- 같은 범위와 품질의 완료 작업끼리 비교한다. 저비용 모델의 반복 실패나 누락이 늘면 그 작업 종류의 기본 모델을 상향한다. 검증 없이 고정 절감률을 주장하지 않는다.
