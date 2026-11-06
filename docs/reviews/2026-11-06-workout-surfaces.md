---
tags: [watchos, live-activity, indoor-place, validation]
date: 2026-11-06
category: solution
status: implemented
---

# 운동 화면 개선 검증

사용자가 Live Activity 상하 여백 수정, Watch 러닝 거리·시간 화면의 존 정보, Watch 실내 유산소의 지도를 요청했다. 존 화면은 V1/V2 시안부터 작성했고 2026-11-06 사용자가 V2 구간 막대 포함을 명시적으로 승인한 뒤 구현했다. 실내 지도는 운동 장소 핀으로 구현했다.

## 실행과 증거

| 범위 | 정확한 selector/명령 | 결과 | 로그 |
|---|---|---|---|
| iPhone 모델 | `DUNETests/WorkoutLocationTests` | 6/6 | `.xcodebuild/indoor-workout-place-unit.log` |
| Watch 수집기 | `DUNEWatchTests/WorkoutRouteRecorderTests` | 15/15 | `.xcodebuild/indoor-workout-place-unit-watch.log` |
| Live Activity | `WatchWorkoutLiveActivityUITests/testGoldCardioDistancePresentation`, `testRunningNotificationCenterPresentation` | 2/2 | `.xcodebuild/workout-surfaces-ui.log` |
| 지도 | `CardioAtlasUITests/testIndoorAutomaticPlacePin`, `testRecordedRouteDetailAndProgress` | 2/2 | 위 iPhone UI 로그 |
| 40mm 러닝 | `WatchWorkoutFlowSmokeTests/testRunningDistanceMetricsAndPausedDesignMap`, `testRunningDistanceShowsPersonalizedZoneCount`, `testRunningDistanceWithoutHeartRateShowsNoZone` | 3/3 | `.xcodebuild/watch-running-zone-ui.log` |
| 문자열 | `swift scripts/format-xcstrings.swift --check --check-manual` | 통과 | 빌드 전후 확인 |
| 카탈로그 계약 | `python3 -B -m unittest scripts.tests.test_format_xcstrings` | 11/11 | 정상 종료 |
| 브라우저 시안 | 4개 상태 × 3/5/7 구간 수 | 12개 조합 통과 | `docs/design/theme-map/themes/assets/watch-running-zone/qa.json` |

단위는 `scripts/test-unit.sh`에 두 selector만 지정하고 1200초 deadline 안에서 순차 실행했다. iPhone UI는 `scripts/test-ui.sh`, Watch UI는 `scripts/test-watch-ui.sh`와 1200초 deadline을 사용했다. 각 실행기의 정상 종료와 0 skip을 확인했다. 요청하지 않은 전체 회귀는 실행하지 않았다. 해당 target은 테스트 과정에서 컴파일했으므로 별도 중복 빌드는 하지 않았다.

## 기기

- iPhone UI: 현재 worktree 소유 iPhone 18 Pro, `58A9B42B-289C-403B-85FE-0D00FACE9A30`.
- Watch UI: 현재 worktree 소유 Apple Watch SE 3 (40mm), `626510D1-97CE-4C2A-987A-96646AA02D97`.
- 단위 전용 기기는 소유 iPhone 17, Watch Series 11 (46mm)을 사용했다. 다른 작업의 기기·프로세스는 조작하지 않았다.
- 이미지별 실제 runtime·기기·시각·원본 해시·결과 번들은 [capture-index.json](../design/phone-design-map/actual/workout-surfaces-2026-11-06/capture-index.json)에 기록했다.

## 실패와 해결

최초 거리 Live Activity는 타이머를 가로 `fixedSize`로 측정하면서 `DUNEWidget`이 종료됐다. 유한한 scaled 폭으로 수정한 뒤 실패한 거리 selector 1건을 재시도해 통과했다. 최종 공통 iPhone 실행에서 시간·거리 카드 2건과 지도 2건을 모두 다시 확인했다. 최초 실패는 `.xcodebuild/live-activity-spacing.log`, 수정 후 단독 결과는 `.xcodebuild/live-activity-spacing-distance-retry.log`에 보존했다.

Watch 결과 번들 export 첫 시도는 실행기 종료 전이라 `Info.plist`가 없어 실패했다. 이후 표준 실행기의 exit 0과 번들 최종 생성을 확인하고 export했다. 테스트를 재실행하거나 미완성 번들을 통과 증거로 쓰지 않았다.

## 검토·한계

SwiftUI 관점에서 시스템 카드 높이와 타이머 proposal, Apple UX 관점에서 거리·시간의 위계와 색에만 의존하지 않는 존 번호, UI 검증 관점에서 카드 본체 경계·미수신·가변 구간·정지 상태를 구분했다. 위치 수집 수명·좌표 검증·세션 정리·수동 장소 우선권·기존 공유 기본값도 확인했다. 위 범위에서 남은 차단 finding은 없다.

[새 실제 화면 8장](../design/phone-design-map/actual/workout-surfaces-2026-11-06/index.html)은 모두 네이티브 XCTest 캡처지만 운동·좌표 데이터는 합성 fixture다. 실내 GPS 수신과 Watch→HealthKit→iPhone 실제 전파는 실기기 미검증이다. iPad·Duo·Island·small·Always-On·큰 글씨·관련 없는 화면은 이번 실행 범위 밖이며 기존 PNG를 새 증거로 대체하지 않았다. 기존 dirty Watch 요약·아이콘 작업은 보존했다. PR·머지는 수행하지 않았다.
