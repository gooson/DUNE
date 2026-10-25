---
tags: [review, life, habits, schedule, accessibility]
date: 2026-10-25
category: solution
status: approved
---

# 오늘의 습관 일정 분리 리뷰

> Base: origin/main dc262ef3. Branch: codex/fix-today-habit-schedule. 앱 소스는 048477a9, 마지막 캡처 테스트 보정은 ac785e81이다. 기존 4592 worktree의 Today/Watch/실행기 변경은 포함하지 않는다.

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 | 0 | — |
| P2 | 4 | 모두 Resolved |
| P3 | 1 | Resolved |

현재 코드의 Open P1/P2/P3는 0건이다. 아래 공통 smoke 실패는 코드 리뷰의 해결된 지적과 구분한다.

## P1 Findings

없음.

## P2 Findings

1. **Architecture / Data Integrity — 날짜 경계 갱신: Resolved.** 열린 Life가 자정을 넘거나 시간대가 바뀌면 분류가 낡을 수 있었다. calendar day/timezone 알림과 active scene 진입에서 동일 재계산 경로를 호출한다. 고정 날짜 테스트가 다음 날 이동을 검증한다.
2. **Apple UX — 시간대 표시 보존: Resolved.** Today/Weekly/Upcoming 모두 기존 `timeOfDayRows`와 행 액션을 재사용한다.
3. **SwiftUI — 선택 카테고리 소멸 후 필터 해제: Resolved.** 마지막 수동 습관을 자동 연동으로 바꿔도 선택 필터가 있는 동안 strip과 All을 유지한다.
4. **SwiftUI 접근성 — 그룹 식별자 덮어쓰기: Resolved.** 바깥 `SectionGroup.accessibilityIdentifier`가 자식 그룹 식별자를 덮어썼다. 기존 제목 전용 `sectionIdentifier` API로 옮겼다. 실제 UI에서 세 그룹 식별자·소속·오늘 1/3 유지가 통과했다.

## P3 Findings

**빈 filtered Today: Resolved.** 선택 카테고리에 오늘 항목이 없으면 빈 그룹을 숨기고, 모든 그룹에 결과가 없으면 번역된 안내를 표시한다.

## Review / Quality Evidence

- Security, Performance, Architecture, Data Integrity, Simplicity의 실제 agent 결과를 보존했다. 마지막 생산 코드 변경은 제목 전용 AX anchor이며 저장·보안·성능 경로가 바뀌지 않았다. 이전 결과와 변경분, 모든 P2를 현재 코드에서 재확인했다.
- SwiftUI, Apple UX, UI Test 관점은 별도로 판단했다. 최종 PR reviewer / app-quality-gate는 전체 기능 리뷰와 이후 변경분을 재검토한다. 대량 데이터 처리가 없어 perf-optimizer는 제외했다. Agent-Native는 지침 변경이 없어 제외했다.
- Localization: 기존 key 수정 없이 Life 전용 key 4개만 추가했으며 en/ko/ja가 모두 있다. View/helper는 LocalizedStringKey, VM은 String(localized:)다. `swift scripts/format-xcstrings.swift --check` 통과.
- 실제 review 결과: `/tmp/habit-review-{security,performance,data,architecture,simplicity}.txt`, `/tmp/habit-final-pr-review-current.txt`, `/tmp/habit-run-apple-ux-current.txt`. finding lifecycle은 `/tmp/review-findings-codex-fix-today-habit-schedule.json`에 기록했다. 이 로컬 증거는 저장소 밖 자료이며 이 문서가 공유 요약이다.

## Validation Scope

자동 판정은 공유 catalog·UI test body·HTML 때문에 iOS/watch full을 제안했다. 소비자 검색에서 새 분류·집계·문구의 사용자는 Life뿐이었다. Watch는 별도 catalog를 사용하며 기존 shared 문자열·App/Domain/Data/seed/helper는 바뀌지 않았다. 사용자 요청 없는 full로 확대하지 않고 관련 Life와 공통 smoke를 실행했다. full iOS/watch, 모든 테마·방향·새 그룹의 모든 큰 글씨 조합은 미검증이다.

| 실행 | 실제 결과 | 증거 |
|---|---|---|
| 관련 unit 3 suites | 45 passed | `/tmp/habit-today-unit.log`; VM/3개 suite 파일 hash 일치 확인 후 재사용 |
| Duo 외부 일정 회귀 | 1/1 passed, exit 0 | `/tmp/habit-run-ui-groups-fixed.log.result.json` |
| 일반 iPhone + 공통 smoke | 38 수행 / 36 passed / 2 failed, exit 65 | `/tmp/habit-run-ui-iphone.log.result.json` |
| 위 실행의 Life 범위 | 16/16 passed | LifeRegression 6, LifeSeededSmoke 2, LifeSmoke 8 |
| iPad 일정·히어로 배치 | 2/2 passed, exit 0 | `/tmp/habit-run-ui-ipad.log.result.json` |
| Duo 내부 일정·히어로 배치 | 2/2 passed, exit 0 | `/tmp/habit-run-ui-duo-open.log.result.json` |
| iPad Upcoming 캡처 보정 | 1/1 passed, exit 0 | `/tmp/habit-run-ui-ipad-capture.log.result.json` |
| generic iOS 최종 빌드 | `scripts/build-ios.sh --no-regen` | `/tmp/habit-run-final-build.log`; 최종 /run 증빙과 PR에 결과 기록 |

Life 관련 실행은 합계 22 passed이며 기기 간 반복 실행을 포함한다. 정상 종료한 결과 번들에서 25개 새 PNG를 원본 그대로 수집했다. iPad는 부분적으로만 보이던 Upcoming 전체를 viewport 안으로 이동한 후 필요한 selector 한 건만 재검증했다. 이전에 통과한 기능·표시 설정을 다시 돌리지 않았다.

### 공통 smoke의 별도 실패와 범위 재확정

- `DashboardSmokeTests/testNavigateToNotificationHub`: Notifications navigation title 조회 실패.
- `DashboardSmokeTests/testNotificationHubSummaryAtMaximumAccessibilitySize`: 알림 설정 버튼 도달성 실패.

Dashboard/NotificationHub, App/Domain/Data, 공유 UI helper/seed, 두 테스트는 base 대비 변경이 없다. shared catalog도 기존 항목을 전혀 바꾸지 않았다. 새 key·집계의 소비자는 Life만이므로 두 실패를 이 작업의 원인으로 판단하지 않았다. adapter의 무관한 실패 처리 규칙에 따라 별도 실패로 보존하고 Life 영향 범위를 재확정했다. 알림 소스 수정·같은 검사 재시도·실패한 전체 묶음의 통과 처리는 하지 않았다. 완성된 xcresult에는 두 실패와 통과한 Life case가 모두 남아 있다.

## Actual Design Map

[새 L01 실제 캡처 25장](../design/phone-design-map/actual/life-schedule-2026-10-25/index.html)과 manifest에 기기·출처 테스트·시각·코드 revision·원본 PNG/AX hash를 보존했다. 일반 iPhone, iPad, Duo 외부·내부의 L01 이미지·기기 갤러리·Life 보드·비교·통합 포털을 갱신했다. 다른 화면은 기존 출처를 유지한다.

새 일정 4개 viewport는 기기마다 영어다. 히어로 밝음·어두움·최대 글씨의 추가 검사는 일반 iPhone/iPad/Duo 내부의 기기 locale로 실행했다. 모든 그룹의 모든 표시 설정을 확인했다는 뜻은 아니다. Morning/Evening 헤더는 코드로 보존을 확인했지만 새 PNG fixture는 Anytime만 포함한다.

Duo는 외부 LCD와 내부 LCD-1 활성 readback, 새 AX/window와 각 화면의 native PNG를 대조했다. 내부는 landscapeRight다. 현재 Xcode 27.1 build27A9275에는 기존 `device motion` 명령이 없어 수치 각도는 미검증이다. 검토한 고정 source의 180° 요청 후 지연 readback에서 LCD-1이 활성화됐으며 setter 성공이나 PNG 크기만으로 전환을 판정하지 않았다.

## Execution History / Remaining Cleanup

최초에는 조사만 했고 습관 수정을 수행하지 않았다. 또한 다른 변경이 있는 4592 worktree를 즉시 분리하지 않았다. 이후 origin/main 기준 전용 worktree를 만들고 구현·검증을 진행했으며 기존 Today/Watch 변경을 이동·커밋·stash하지 않았다. 이번 /run은 당시 미완료였던 UI·실제 캡처·문서화·Ship까지 포함한다.

초기 clone 등록의 닫힌 lock FD, 폼 주기 선택/Save 탐색, SDK 결과 정리 정체, 그룹 AX 덮어쓰기와 인자 순서 컴파일 오류는 원인별 증거와 수정·재시도 이력을 보존했다. 현재 focused UI는 정상 결과를 만들었다. 이력은 `.codex-checks/habit-run/`에 있으며 미실행/0개/중단을 통과로 바꾸지 않았다.

등록 실패 당시 생긴 orphan simulator `2ABB7180-5817-4F39-B5FA-A95463D3F9C5`의 복구 표식은 남아 있다. Ship adapter는 이 기기를 자동 삭제하지 않고, 복구 표식이 남으면 worktree/브랜치 후처리를 멈추도록 한다. 원격 머지 결과와 실제 정리 결과는 최종 Ship 보고에서 구분한다.
