# 테스트 실행과 검증 재사용

모델 배정은 `agent-map.md`, 공통 위임은 `skill-compat.md`를 따른다. 이 문서는 테스트/검증 단계에서만 읽는다.

## 실행과 출력

- 명령 실행/대기는 셸 도구에 맡긴다. 실행만을 위한 모델이나 별도 agent를 생성하지 않는다.
- 표준 실행기: `scripts/test-unit.sh`, `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`. 기본 파일 로그와 요약을 사용하고, 로그 전체를 `cat`하지 않는다. CI streaming 기본 동작은 유지한다.
- 정상 결과는 종료 상태·로그 경로·보고된 테스트 수만 확인한다. 실패 시 제한된 오류 요약 → 해당 로그 구간 → 관련 소스 순서로 읽는다. 요약에서 수를 알 수 없으면 unknown이며 0건 성공으로 간주하지 않는다.
- 개발 중 `test-ui.sh --only-testing <target/class/method>` 또는 `--smoke`로 빠르게 확인할 수 있다. 최종 게이트는 source skill이 요구하는 full suite/device 범위를 유지한다. 단위 테스트의 `--ios-only`/`--watch-only`는 실제 변경 범위와 최종 요구조건에 맞게 사용한다.
- simulator 부팅 등 환경 오류와 앱/테스트 실패를 먼저 구분한다. 근거 없이 같은 명령을 반복하지 않는다. 실제 수정 후 관련 실패를 재확인하고 필요한 전체 검증을 완료한다.
- 제스처/차트/레이아웃 관련 source 규칙의 seeded/mock 재현 의무는 유지한다. 요소 존재만으로 시각적 레이아웃 전체를 검증했다고 보고하지 않는다.

## 동일 검증 증거

`scripts/codex-check.py`는 명령을 실행하는 `run`과 성공 증거만 확인하는 `check`를 제공한다. 테스트를 자동으로 건너뛰지 않는다. 동일한 작업의 뒤 phase에서 이미 수행한 검증을 재사용할 때만 `check`를 명시적으로 호출한다.

```sh
python3 scripts/codex-check.py run parity --context 'adapter-check-v1' -- python3 scripts/check-codex-claude-parity.py
python3 scripts/codex-check.py check parity --context 'adapter-check-v1' -- python3 scripts/check-codex-claude-parity.py
```

- 이름, 명령 argv, context, worktree/HEAD, tracked 및 nonignored untracked 파일 내용이 일치하고 성공 로그가 남아 있어야 한다. 실패/중단/실행 중 변경/증거 누락이면 재사용하지 않는다.
- context는 같은 phase 이름이 아니라 **실행 환경 식별자**다. Xcode 검증은 Xcode/SDK 버전, simulator UDID/runtime, scheme/test plan, locale, launch/seed 조건, 관련 환경 변수의 안전한 식별자를 포함한다. 비밀 값은 기록하지 않는다.
- ignored 파일, 외부 의존성, simulator/app 데이터, 환경 변수는 worktree fingerprint만으로 보장되지 않는다. 재사용 직전에 그대로인지 확인하고 context를 갱신한다. 확인 불가, flaky 테스트, 권한/상태 변경이면 `run`으로 다시 실행한다.
- helper는 gate 범위를 판단하지 않는다. smoke/관련 테스트 증거를 full suite로, iPhone 증거를 iPad/watch 증거로 사용하지 않는다. 실행 전후 파일 변경이 있으면 명령 자체가 성공해도 재사용 증거로 인정하지 않는다.
- `check` 실패는 테스트 실패와 구분한다. 현재 요구 범위로 `run`을 수행하고 새 결과로 판단한다. 로그 저장소 `.codex-checks/`는 로컬 전용이며 수동 삭제하면 증거가 무효화된다.
- compiler/test runner가 일부 테스트만 수행했는지, skip/0 tests/예상 suite 누락이 없는지도 확인한다. 종료 코드 0만으로 요구 커버리지 충족을 선언하지 않는다.

## Review / Quality 재사용

- 이전 리뷰의 base/대상 diff, 관점, 결과/미해결 findings를 기록한다. 동일 diff·규칙·관점의 완료된 결과만 다음 phase에서 참조한다. 코드 변경 후에는 관련 관점을 재검토한다.
- 자동 테스트 receipt는 사람/agent의 리뷰를 증명하지 않는다. 리뷰 결과가 없으면 각 필수 관점을 수행한다. PR의 통합/크래시 검증은 이전 findings와 이후 diff를 함께 확인한다.
- 단계별 출력에는 수행 또는 재사용 여부와 실제 증거 경로를 한 줄로 남긴다. parent와 child가 같은 검증을 중복 수행하지 않게 소유자를 지정한다.

## 절감 효과 확인

- 대표 사례는 단순 테스트 추가, UI 테스트 실패 수정, 일반 기능 구현으로 나눈다. 기존 작업의 기록을 baseline으로 사용하며 비용 측정만을 위해 전체 파이프라인을 반복하지 않는다.
- 작업별 모델/추론, 입력·캐시·출력 토큰(도구가 제공할 때), 재시도/상향 횟수, 명령 실행/재사용 횟수, 테스트 결과와 발견된 오류를 기록한다. 제공되지 않는 지표는 unknown으로 남긴다.
- 토큰 수, API 비용, Codex 계정 사용 한도는 별도 지표다. 문자/로그 줄 수 감소를 토큰 또는 계정 사용량 절감률로 환산하지 않는다. 계정 사용량은 다른 작업의 영향을 받는다.
- 같은 범위와 품질의 완료 작업끼리 비교한다. 저비용 모델의 반복 실패나 누락이 늘면 그 작업 종류의 기본 모델을 상향한다. 검증 없이 고정 절감률을 주장하지 않는다.
