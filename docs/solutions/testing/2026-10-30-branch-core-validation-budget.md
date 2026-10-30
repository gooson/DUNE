---
tags: [codex, skills, targeted-tests, process-budget, simulator, screen-lock]
date: 2026-10-30
category: testing
status: implemented
severity: important
related_files:
  - AGENTS.md
  - .codex/skill-compat.md
  - .codex/token-efficiency.md
  - .codex/ui-execution.md
  - scripts/lib/xcodebuild-resources.sh
  - scripts/build-ios.sh
  - scripts/build-target.sh
  - scripts/hooks/pre-commit.sh
  - scripts/test-unit.sh
  - scripts/test-ui.sh
  - scripts/test-watch-ui.sh
related_solutions:
  - 2026-10-30-unit-test-selection.md
  - 2026-10-25-session-audit-and-ui-host-context.md
---

# Solution: 모든 스킬의 브랜치 검증 범위와 실행 예산 통일

## Problem

`/run`에는 targeted 검증 예외가 있었지만 standalone 스킬에는 원본의 전체 실행 요구가 남아 있었다. `full` 판정을 실제 실행하지 않으면서도 필수 미완료 게이트로 남기는 문구, 매 feature에 공통 smoke를 합치는 문구가 중복 검증을 유발했다. build에는 jobs 4 제한이 있었으나 test 실행기에는 job 제한이 없었다. Mac 화면 잠금을 guest XCTest까지 막는 근거로 잘못 해석할 여지도 있었다.

## Solution

`.claude/**`는 보존하고 Codex adapter의 명시적 사용자 예외로 적용했다. canonical 정책은 `.codex/skill-compat.md`의 「모든 스킬의 핵심 검증과 점유 예산」이다.

| 변경 | 적용 결과 |
|------|-----------|
| 모든 스킬의 실행 범위 통일 | 변경 동작·소비자·플랫폼의 핵심 unit/UI selector로 검증. 사용자 요청 없는 로컬 full 회귀는 완료 조건에 추가하지 않음 |
| 단계 간 증거 공유 | 같은 target의 컴파일을 포함한 테스트 뒤 별도 build-only 반복 방지. 수정 후에는 영향받는 검사만 갱신 |
| 공통 resource helper | 로컬 build-ios/build-target/unit/iOS UI/watch UI에 jobs 2·index store NO, 로컬 unit 병렬 테스트 NO. 커밋 훅의 target compile도 포함. 기존 UI 직렬 실행 유지 |
| CI 분리 | CI build-ios 기본 jobs 4·index store NO, build-target/test의 기존 병렬성·job 기본값 보존. 명시적 환경 변수 override 지원. helper와 계약 파일을 CI 경로 필터 및 계약 suite에 연결 |
| 실행 예산 | 한 worktree에 무거운 실행 하나. build 900초·targeted 검사 1200초를 시작 예산으로 하고 기존 소유 프로세스 watchdog 사용. 커밋 훅의 build에도 기본 900초 watchdog 적용 |
| 잠금 진단 | host 잠금만으로 중단 금지. 현재 selector의 CLI XCTest·guest PNG·필요한 Duo readback 확인 후 실제 실패 근거로 제약 판단 |

예를 들어 단위 테스트는 다음처럼 전체 target 대신 실제 class를 선택한다. build/unit의 deadline은 스킬 실행자가 기존 wrapper로 적용하며, 새 resource helper가 자체 watchdog을 제공하는 것은 아니다.

```bash
python3 scripts/lib/command-deadline.py --seconds 1200 -- scripts/test-unit.sh --ios-only --only-testing DUNETests/CalculateConditionScoreUseCaseTests
```

`DAILVE_XCODEBUILD_JOBS=1`로 더 줄일 수 있다. jobs는 Xcode build 작업 제한이며 모든 compiler/Simulator 프로세스나 host CPU 사용률을 직접 제한하지 않는다. 실제 절감률은 측정하지 않았다.

## Prevention

- 문서만 변경한 요청은 diff·참조·parity로 완료하고 앱을 실행하지 않는다.
- 공유 계산 변경도 호출부를 확인해 필요한 플랫폼의 경계·오류 검사를 선택한다. 공유 폴더 또는 판정기의 `full`을 전체 실행 허가로 취급하지 않는다.
- UI 변경은 실제 영향 상태·기기의 핵심 동작과 디자인맵 캡처를 유지한다. targeted 성공을 전체 회귀 성공으로 보고하지 않는다.
- 잠긴 Mac의 GUI 조작 실패만으로 불가 판정하지 않는다. 기존 잠금 상태 성공 근거와 검토된 CLI를 사용하며, 실패 경로·오류·대안·미검증 범위를 구체적으로 기록한다.
- job 설정의 로컬/CI 기본값·override·잘못된 값, 실제 실행 argv와 선택 범위는 `scripts/tests/test_xcodebuild_resources.py`의 fake-tool/dry-run 계약으로 검증한다. 이 검증은 실제 SDK 실행·CPU 측정을 대신하지 않는다.

## Lessons Learned

검증 비용은 실행 범위와 프로세스 예산을 함께 줄여야 낮아진다. 스킬별 예외를 쌓는 대신 한 기준으로 우선순위를 정하고, 환경 제약은 실제 실패 단계와 증거로 판단한다.

## Verification

- 최초 resource helper 7개, unit routing/0건 처리 2개, iOS receipt와 Watch 필수 selector/종료 코드 3개: 총 12개 Python 계약 통과. fake tools와 dry-run을 사용했으며 실제 Xcode·Simulator는 기동하지 않았다.
- review-ship에서 CI 연결 누락, 커밋 훅 build-target의 예산 우회, 커밋 훅 build의 deadline 누락을 P2로 발견해 수정하고 재리뷰에서 모두 Resolved로 확인했다.
- 최종 resource 계약 9개 통과: build-target의 실제 argv/CI 기본값과 훅 full/target build의 watchdog 인자·124 종료 코드 전파를 추가 확인했다. 변경 없는 unit/UI 결과 5개는 재사용했다.
- 변경 shell 7개의 `bash -n`, workflow 3개의 YAML/필터/계약 연결, Codex/Claude parity, `git diff --check` 확인.
- 첫 계약 실행의 session ID 수집 누락으로 최종 요약을 회수하지 못했다. 기존 프로세스 종료를 확인한 뒤 위 핵심 12개만 한 번 재확인했고, 결과는 `/private/tmp/health-core-validation-budget-tests.log`에 저장했다. 원래 실행을 통과로 집계하지 않았다.
