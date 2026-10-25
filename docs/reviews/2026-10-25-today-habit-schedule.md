---
tags: [review, life, habits, schedule]
date: 2026-10-25
category: solution
status: draft
---

# 오늘의 습관 일정 분리 리뷰

> Base: origin/main (94c29d36). Branch: codex/fix-today-habit-schedule. 기존 4592 worktree의 Today/Watch/실행기 변경은 포함하지 않는다.

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 | 0 | — |
| P2 | 3 | Resolved (코드 재확인, UI gate 미완료) |
| P3 | 1 | Resolved |

## P1 Findings

없음.

## P2 Findings

1. Architecture / Data Integrity: 열린 Life가 자정을 넘으면 Today/Upcoming과 당일 완료가 낡은 상태로 남음. **Resolved**: calendar day/timezone 알림과 active scene 진입에 재계산을 연결했다.
2. Apple UX: Weekly/Upcoming에서 기존 시간대 표시가 빠짐. **Resolved**: 세 그룹이 공통 timeOfDayRows를 사용한다.
3. SwiftUI: 선택한 카테고리의 마지막 수동 습관을 자동 연동으로 편집하면 카테고리가 사라져 필터를 해제할 수 없음. **Resolved**: 선택 필터가 있는 동안 필터 strip과 All을 유지한다.

## P3 Findings

SwiftUI / Apple UX: 카테고리 필터에서 빈 Today 0 그룹이 남음. **Resolved**: 빈 filtered Today는 숨기고 전체 필터 결과가 없으면 번역된 안내를 표시한다.

## Positive Observations

- Security/Performance/Simplicity: 신규 문제 없음. 저장 스키마·기록 CRUD·알림 정책은 변경하지 않는다.
- Agent-Native는 지침 변경이 없어 제외했다.
- Localization: 네 새 key에 en/ko/ja가 있고 helper는 LocalizedStringKey, VM은 String(localized:)를 사용한다. xcstrings format check 통과.
- 단위 테스트는 today/weekly/upcoming 분류와 조기 완료 다음날 이동을 고정 날짜로 검증한다.

## Validation Scope

자동 UI 판정은 공유 catalog·UI test body·HTML 때문에 iOS/watch full을 제안했다. 실제 변경 symbol 소비자는 Life뿐이며 catalog에는 Life 전용 새 key만 추가했다. Watch/Widget/visionOS 소스와 기존 문자열은 그대로다. 사용자 요청 없는 전체 테스트로 확대하지 않고 관련 3개 unit suite와 LifeRegressionTests 및 Life smoke를 선택한다. targeted 성공을 full 성공으로 보고하지 않는다.

## Execution Evidence / Next Steps

- generic iOS 빌드: 24bcfbdc 커밋 전 pre-commit scripts/build-ios.sh --no-regen 통과. 이후 최종 UI 수정은 단위/UI test build에서 확인할 대상이다.
- unit 최초 시도: 테스트 0개. clone 소유권 등록의 Bad file descriptor 환경 실패. 등록 프로세스에서 닫힌 lock FD가 전달된 것이 원인이었다. 저장소 파일 수정 없이 부모 lock 유지 + 자식 stale FD 제거로 별도 전용 기기를 등록했다.
- unit 재시도 1/1: 전용 Duo clone C9AF35FA-EC0F-421E-9D3B-23B15B77A655, /tmp/habit-today-unit.log, 3 suites / Swift Testing 45개 통과. 실행기 요약의 XCTest 0개와 별개로 로그의 `Test run with 45 tests in 3 suites passed` 및 `TEST SUCCEEDED`를 직접 확인했다.
- 최초 clone 2ABB7180-5817-4F39-B5FA-A95463D3F9C5에는 orphan marker가 있다. 자동 삭제하지 않으며 worktree를 보존한다.
- UI 최초 실행: 위 전용 Duo 외부 화면에서 3개 selector의 testcase 실행이 끝났다. 기본 Life 2개 통과 / 새 회귀 1개 실패. 새 테스트가 폼 대신 앱 CollectionView를 스크롤한 fixture 오류이며 기존 primary-form helper 사용으로 수정했다. 테스트 종료 후 Xcode 결과 writer가 멈춰 Info.plist 없는 xcresult만 남았다. 검증된 이번 작업 watchdog PID 95834에 SIGTERM을 보내 종료했고 실행 exit는 130이다. 종료 때 EPERM 경고가 있어 PID 95834/95850/95938이 사라졌음을 확인했다. 별도 session의 simctl diagnose PID 98500은 남았으므로 강제 종료하지 않고 UI 재시도를 보류했다. 수정한 fixture는 미실행이다. 공식 devicectl readback에서 활성 LCD, portrait를 확인했다. 정상 종료·정확한 selector 수·새 PNG 확인 전에는 통과로 간주하지 않는다.


## Final Status / Recovery

- 코드 리뷰: 미해결 P1/P2 없음. 최종 통합 검토 `/tmp/habit-final-pr-review.txt`와 finding JSON에 근거가 있다. 마지막 64a86a0d는 기존 primary-form 스크롤 헬퍼로 fixture를 고친 변경이다.
- UI 실행의 testcase 결과: 3개 수행, 기본 Life 2개 통과 / 새 분류 회귀 1개 실패. 정상 종료·완성된 xcresult가 없어 UI gate는 실패/미완료다. 실패 테스트의 fixture 수정 후 재시도는 아직 0/1이다.
- 남은 SDK 진단 프로세스가 종료되고 UI 실행 환경에서 정상 xcresult writer가 확인되면, 단일 regression selector부터 수정한 fixture를 1회 검증한다. `DUNE_UI_TEST_WALL_TIMEOUT=420 DUNE_UI_TEST_IDLE_TIMEOUT=90`을 명시해 결과 정리 대기를 제한한다. 이어 관련 Life suite/공통 smoke를 확인한다. 관련 범위를 넘어 전체 테스트로 확대하지 않는다.
- L01의 iPhone·iPad·Duo 외부/내부, 밝음/어두움/큰 글씨 캡처는 이번 버전으로 갱신하지 못했다. 기존 PNG는 변경 전 기록이며 완료 증거가 아니다. Watch는 Life 화면을 공유하지 않아 이번 변경 영향이 없다.
- PR 생성·원격 머지·브랜치/워크트리/시뮬레이터 정리를 실행하지 않았다. 원격의 작업 브랜치와 현재 worktree를 보존한다. orphan marker 기기는 자동 삭제하지 않는다.
- 사용자 원요청은 습관 조사였으나 기존 Today feature 브랜치에서 진행한 것은 작업 격리 실수였다. 코드 수정 전 origin/main 기준 전용 worktree와 `codex/fix-today-habit-schedule` 브랜치를 만들었으며 기존 4592 변경을 이동·커밋·stash하지 않았다.
