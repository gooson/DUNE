---
tags: [review, activitykit, watchconnectivity, release-gate]
date: 2026-10-25
category: review
status: blocked
---

# Code Review Report

> Date: 2026-10-25
> Scope: Watch 운동 Live Activity 디자인·DUNE 표시·종료 정리
> Base: origin/main f4d56f63
> Files reviewed: 23개 (기존 Today 브랜치 커밋·다른 디자인 작업 제외)

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 - Critical | 0 | 없음 |
| P2 - Important | 2 | 1건 Resolved · 1건 Open (ship 차단) |
| P3 - Minor | 0 | 없음 |

## P1 Findings (Must Fix)

없음.

## P2 Findings (Should Fix)

### [Data Integrity] data-001 · 종료 identity를 하나만 보존

- **File**: DUNE/Presentation/Exercise/WatchWorkoutActivity.swift:79
- **Category**: data / recovery
- **Issue**: A·B 종료가 모두 먼저 도착하면 A 종료가 덮어써져 지연 A attach가 카드를 다시 생성할 수 있다.
- **Suggestion**: 정확한 시작 시각별 bounded terminal history를 사용하고 회귀 사례를 추가한다.
- **Disposition**: Resolved. 시작 시각별 최근 32개 종료 기록을 보존한다. A 종료→B 종료→지연 A attach 회귀 테스트 통과 및 Data Integrity 재검토 완료.

### [App Quality] verify-001 · 필수 시스템 UI 증거 미완료

- **File**: DUNEUITests/Full/WatchWorkoutLiveActivityUITests.swift:20
- **Category**: verification
- **Issue**: 이전 UI 실행은 3건 통과·stale 1건 실패 뒤 SDK 정리가 멈춰 exit124다. 최신 워드마크·종료 후 제거의 새 정상 결과·캡처가 없다.
- **Suggestion**: SDK 정리 정상화 증거 후 실패 selector와 최신 브랜드 selector부터 재검증한다. 기존 PNG·core mock 결과를 최신 시스템 검증으로 승격하지 않는다.
- **Disposition**: Open. 머지 차단.

## P3 Findings (Consider)

없음.

## Review Perspectives

- Security·Performance·Architecture·Simplicity: 구체적 코드 finding 없음.
- Data Integrity: data-001.
- Agent-Native: 해당 파일 변경 없어 skip.
- Localization (parent): 새 번역 대상 키 없음. DUNE는 verbatim 브랜드, bpm/kcal는 단위다. 기존 Workout/Paused/Workout Ended/Waiting for Watch의 en·ko·ja와 접근성 레이블을 유지한다.
- SwiftUI·Apple UX·UI Testing (parent): 시스템 표면과 named colors, 정보 위계·민감 정보·상태별 표시를 확인했다. 실제 워드마크·작은 표면·Island·큰 글씨의 육안 인증은 없다.

## Excluded Observation

늦은 이전 HealthKit callback의 기존 abandoned-activity cleanup은 origin/main에도 동일하다. 이번 변경에서 도입한 코드가 아니므로 별도 작업으로 분리하고 이 PR 수정 범위를 확대하지 않는다.

## Positive Observations

- 별도 origin/main 작업 트리에서 이번 파일만 분리해 다른 Today·테마 작업을 포함하지 않았다.
- 종료 패킷의 크기·phase·수치와 세션 시각을 검증하고, 전송과 lifecycle 순서 검증을 분리했다.
- 기존 실패·미검증과 정상 빌드·core 테스트를 구분했다.

## Next Steps

- data-001 Resolve 및 해당 회귀 검증.
- verify-001이 Open인 동안 PR 생성·머지·원격 브랜치 삭제·로컬 정리를 진행하지 않는다.

## Resolve와 검증 결과

- data-001: **Resolved**. 단일 종료 기록을 시작 시각별 최근 32개 이력으로 바꾸고 `retainsEarlierTerminalIdentity` 회귀 테스트를 추가했다.
- verify-001: **Open**. 실패한 UI 상태·최신 워드마크·실제 Watch 종료 후 제거의 정상 시스템 검증이 없다. 새 작업 트리나 phase 전환으로 기존 SDK 실패 재시도 예산을 초기화하지 않았다.
- 기존 Security·Performance·Architecture·Simplicity 판단은 변경 후에도 해당 범위에서 유효함을 parent가 재확인했다. delta는 private bounded dictionary와 회귀 사례뿐이며, Data Integrity reviewer가 해당 P2만 다시 확인했다.
- 통합 빌드: `.codex-checks/evidence/precommit-ios-build.log` **BUILD SUCCEEDED**.
- 실제 core/controller/parser/snapshot 테스트: `.codex-checks/evidence/watch-end-core-tests.log` **36 passed / 0 failed**. macOS Swift Testing으로 시스템 드라이버를 제외한 보조 검증이며 native iOS·paired-device 증거는 아니다. source-manifest의 현재 파일 해시를 확인했다.
- xcstrings 포맷 및 `git diff --check`: 통과.
- Agent-Native·번역 delta: 관련 변경 없음. 이름·단위 면제와 기존 ko/ja 상태 레이블을 확인했다.

## Ship 상태

`review-ship`의 “Stop before shipping if a P1/P2 finding remains open or required verification is failing or unavailable.” 규칙에 따라 **PR 생성·push·merge를 실행하지 않았다**. 최종 원격 PR 리뷰·GitHub checks·원격 merge 확인과 merge 후 로컬/시뮬레이터 정리도 실행하지 않았다. 관련 코드와 리뷰는 `codex/watch-live-activity`에 보존한다. 원래 `codex/today-design-fidelity` 브랜치의 커밋·외부 테마 작업을 포함하거나 정리하지 않았다.

SDK 결과 정리가 정상 종료됨을 확인한 뒤 이 작업 트리에서 실패 상태와 최신 브랜드부터 재개한다:

```bash
DAILVE_IOS_SIMULATOR='iPhone 18 Pro' DUNE_UI_TEST_WALL_TIMEOUT=600 DUNE_UI_TEST_IDLE_TIMEOUT=180 scripts/test-ui.sh --no-regen --only-testing DUNEUITests/WatchWorkoutLiveActivityUITests/testStaleNotificationCenterHidesOutdatedMetrics --only-testing DUNEUITests/WatchWorkoutLiveActivityUITests/testLongStrengthNameNotificationCenterPresentation --log-file .xcodebuild/live-activity-resume-ui.log
```

이 명령은 정상화 확인 전에는 다시 실행하지 않는다. runner가 선택한 이 작업 트리 전용 clone의 소유권과 결과 receipt를 확인하고, 영향받는 상태의 최신 캡처를 갱신한다. UI·실제 쌍 기기 미확인 범위를 정상 테스트로 바꾸지 않는다. 검증 통과 후 최종 PR review 및 사용자 요청의 Ship를 이어간다.

로컬 커밋의 표준 pre-commit 훅이 `.xcodebuild`를 삭제하고 동일 앱 소스의 통합 빌드를 다시 확인해 통과했다. 그 원본 로그를 `.codex-checks/evidence/precommit-ios-build.log`에 보존했다. 삭제된 코어 로그도 같은 입력 해시의 36개 테스트를 실행해 `.codex-checks/evidence/watch-end-core-tests.log`에 다시 보존했다. 문서의 증거 경로만 정정하는 amend에서는 이미 통과한 동일 소스 빌드를 반복하지 않게 훅의 명시된 `DAILVE_SKIP_PRECOMMIT_BUILD=1` 옵션을 사용한다. UI gate나 원격 검증을 우회한 것은 아니다.
