---
tags: [today, weather, review, concurrency, ship, validation]
date: 2026-11-14
category: solution
status: verified
---

# Today 날씨 로딩 Review and Ship

## Scope

실제 PR base는 `origin/main`이다. 시작 폴더 `detail-posture-b05/Health`의 `codex/theme-overhaul-completion`에는 이 작업과 무관한 17개 테마 커밋이 있었다. 기본 checkout도 Watch scheme 3개가 이미 수정된 상태였다. 기존 작업을 함께 커밋하거나 stash하지 않고, `origin/main`의 전용 `fix/today-weather-loading` 한 곳으로 이번 7개 tracked 파일의 delta와 새 검증/캡처/해결책 파일만 옮겼다. 원래 테마 폴더는 해당 17개 커밋을 유지한 채 clean으로 복구했다. 새 worktree는 격리를 위해 필요한 하나만 만들었다.

브랜치의 committed/staged/unstaged/untracked 전체를 검토했다. review 시 task commit은 없었고 base와 HEAD는 동일했다. Presentation/Domain의 새 사용자 대면 문자열과 catalog 변경은 없어 [L10N] 5개 leak 패턴에 새 finding은 없다. Agent-Native는 지침·prompt 변경이 없어 생략했다.

## Review Summary

| Priority | Count | Disposition |
|----------|-------|-------------|
| P1 | 0 | 없음 |
| P2 | 4 | 4 Resolved |
| P3 | 0 | 없음 |

Security·Performance·Architecture·Data Integrity·Simplicity를 각각 `gpt-6-sol`, medium, read-only agent로 검토했다. Architecture/Data의 중복 두 건은 통합했다. 별도 final `pr-reviewer`와 `app-quality-gate` 관점의 재검토에서도 새 production P1/P2는 없었다. 상세 상태는 [review-findings.json](review-findings.json)을 따른다.

## P1 Findings

없음.

## P2 Findings

1. **arch-001 · Resolved:** 건강 문맥 생성 후 sparkline await 중 `isLoading`이 true이면 늦은 날씨의 코칭 갱신이 누락됐다. 완료된 건강 데이터가 있는지(`hasLoadedOnce`)로 판단한다. 회귀는 실제 sparkline을 중단시키는 통합 검사가 아니라, 건강 데이터를 로드한 뒤 `isLoading = true`인 유효한 상태를 구성해 해당 분기를 확인한다.
2. **arch-002 · Resolved:** 권한 재조회와 background 날씨가 같은 load ID에서 경합했다. 두 경로를 공통 weather generation으로 무효화하고, 양쪽 완료 순서의 회귀를 추가했다. 취소된 권한 대기도 종료한다.
3. **perf-001 · Resolved:** 날씨 도착 때 같은 AI 코칭을 취소·재시작했다. 생성된 원래 template이 같으면 기존 강화 문구와 진행 중 inference를 유지한다. 실제 Task 종료 후 mock enhancer 호출이 1회임을 확인한다.
4. **simp-001 · Resolved:** 과거 응답 회귀가 고정 20ms sleep에 의존했다. read-only Task handle로 실제 이전 응답 처리 완료를 기다린 뒤 상태를 검증한다.

## P3 Findings

없음.

## Validation

최종 소스는 이전 테마 작업의 검증을 그대로 합격 증거로 삼지 않고 전용 worktree에서 다시 검증한다. 한 worktree에서 build/unit/UI는 하나씩, jobs 2·index store OFF·테스트 병렬 OFF를 유지했다. 각 실행 deadline은 1200초다. 로컬 full 회귀는 요청하거나 실행하지 않았다.

- `scripts/test-unit.sh --ios-only --only-testing DUNETests/DashboardViewModelTests`: **44 passed / 0 failed / 0 skipped, exit 0**. [원본 summary](isolated-unit-summary.json), [44개 개별 결과](isolated-unit-tests.json).
- 최종 iPhone 18 Pro `F4F30F9E-3501-4F33-A896-8471AFDE0371`: **1 passed / 0 failed / 0 skipped, exit 0**. [receipt](isolated-phone-result.json).
- 최종 iPad mini (A20 Pro) `35F97821-5391-4E20-A302-46C085BD2977`: **1 passed / 0 failed / 0 skipped, exit 0**. [receipt](isolated-ipad-result.json).

두 UI 실행은 `DUNEUITests-DesignCapture` plan에서 `DUNEUITests/NotificationResponseRoutingUITests/testNotificationResponseOpensSummaryAndBackReturnsToToday` 하나만 선택했다. `DAILVE_IOS_SIMULATOR`와 `DAILVE_IOS_OS=27.2`로 원본 기종을 정하고 표준 실행기가 이 worktree의 clone을 생성·등록했다. `DAILVE_UI_TEST_DERIVED_DATA_DIR=.deriveddata/unit-tests`를 사용해 현재 worktree의 빌드 캐시만 재사용했다.

최종 소스의 T03/T10 PNG·AX **4쌍**을 새로 수집해 직접 확인했다. 실제 컨디션 84, 활동 수치, 스켈레톤 종료와 기본 세로 viewport를 확인했으며 아래 스크롤 내용을 한 viewport에서 모두 검사했다고 주장하지 않는다. [현재 소스 SHA-256·결과 출처](source-and-results.json)와 [최종 4장·보완 전 6장 구분 갤러리](../../design/phone-design-map/actual/today-loading-2026-11-14/index.html)를 보존했다. 이전 소스 해시·40건 단위·4회 UI는 이력이고 최종 소스의 합격 증거는 아니다.

앱 소스와 UI test body가 위 실행 뒤 바뀌지 않았음을 SHA-256으로 확인했다. 커밋 hook의 추가 앱 빌드는 `DAILVE_SKIP_PRECOMMIT_BUILD=1`로 생략하고 동일 target 컴파일을 포함한 위 통과 결과를 재사용한다. secret 검사 등 나머지 commit hook은 실행하며 `--no-verify`는 사용하지 않는다.

## Limits and Cleanup

실제 신고 기기의 지연 요청은 로그가 없어 확정하지 않았다. 날씨 지연으로 건강 화면 전체가 대기하는 의존을 수정한 것이다. 실제 HealthKit 응답 시간이나 알림 전달 시간 전체를 검증한 것은 아니다. Duo 목표 접힘·펼침 가로의 새 PNG는 이 작업에서 인증하지 않는다.

기본 checkout의 기존 Watch scheme 수정은 이 작업 범위 밖이므로 보존한다. 원격 머지 후에도 이 상태가 남으면 canonical cleanup의 main-clean precondition을 충족하지 못하므로 primary pull과 worktree 제거를 임의로 진행하지 않는다.


## CI 한도 초과 보완 · 후속 요청

최초 GitHub run `43604236903`의 iOS job은 시작 21분 후(`14:40:34Z`) Swift Testing을 시작했고, named test 1,469건 통과·0건 실패 상태에서 `14:49:52Z`에 취소됐다. 이 수치는 **부분 실행**이며 전체 통과가 아니다. 빌드 CI와 Watch 단위 CI는 통과했다. 사용자의 “다해결해 / 머지까지 완료해” 후속 요청에 따라 이 차단 원인을 같은 PR 범위에서 해결한다.

`.github/workflows/test-unit.yml`의 matrix에 iOS 60분·Watch 30분을 명시했다. iOS의 cold compile·전체 단위 실행·결과 보존을 수용하는 유한 예산이며 full suite, 플랫폼 분리, fail-fast, runner 명령과 리소스 기본값은 유지한다. GitHub의 [context availability](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability)는 job timeout에서 matrix 사용을 허용한다.

Ruby YAML parse로 workflow 구조·양 플랫폼·한도를 확인했고, `CI=true scripts/test-unit.sh --ios-only/--watch-only --dry-run`으로 여전히 각각 `DUNETests`/`DUNEWatchTests` 전체 target을 선택함을 확인했다. 시뮬레이터·앱 실행을 추가하지 않았다. final PR/quality agent의 변경분 재검토는 새 P1/P2/P3 없음이다. [CI 취소 진단](ci-timeout-diagnosis.json)에 시각·부분 결과·변경 이유를 보존한다.

앱 및 unit/UI test source SHA-256은 기존 최종 검증과 같으므로 로컬 44건·두 UI 검증과 캡처를 재사용한다. 한도를 실제로 변경한 새 GitHub CI 결과를 확인한 뒤 머지한다. 이전 cancelled job을 통과로 바꾸어 표현하거나 검사를 제거하지 않는다.
