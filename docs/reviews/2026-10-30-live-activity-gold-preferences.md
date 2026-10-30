---
tags: [live-activity, activitykit, gold, preferences, verification]
date: 2026-10-30
category: review
status: ui-blocked
---

# Gold Impact · 종목별 주 지표 검증

대상 브랜치는 `codex/live-activity-gold-preferences`이며 최신 main 통합 후 구현 기준은 `93fa6959`이다. [계획](../plans/2026-10-30-live-activity-gold-preferences.md), [레이아웃 계약](../design/layout-map/watch-workout-live-activity.md), [보존 시안](../design/theme-map/themes/dune-live-activity-size-state.html), [해결 문서](../solutions/architecture/2026-10-30-live-activity-gold-preferences.md)를 함께 따른다.

## 검증 범위

전체 프로젝트 회귀를 실행하지 않는다. 새 optional Watch metadata, 현재 편집 중량의 lifecycle, 표시 선택값의 저장·직렬 갱신·ActivityKit 인코딩, 관련 Settings와 시스템 Live Activity 상태만 검증한다. Watch 화면의 배치는 바꾸지 않았으며 Watch 테스트는 전송할 현재 값과 전환 초기화를 확인한다. iPad·Duo Settings, Dynamic Island 각 크기·제한 폭, Watch/CarPlay small 및 StandBy의 실제 캡처는 별도 결과가 있기 전까지 미검증이다.

## 완료된 증거

| 항목 | 결과 | 범위 |
|---|---|---|
| 일반 기기 빌드 | 통과 | `scripts/build-ios.sh --no-regen`, iOS·Widget·embedded Watch, 93fa6959 |
| 네이티브 iOS 단위 | 46 통과 | WatchWorkoutSnapshotTests, WorkoutLiveActivityPreferencesTests, WatchWorkoutAttributesTests, WatchWorkoutActivityTests |
| 네이티브 Watch 단위 | 5 통과 | WorkoutManagerReorderTests |
| Settings UI | 1 통과 | 종목별 선택과 스타일 저장·앱 재실행 유지, 5ef25439 |
| 문자열 | 통과 | formatter/manual extraction 검사 및 일반 빌드 후 검사 |
| 테마 맵 | 통과 | 보존 study·manifest·README와 생성 인덱스 동기화 |
| UI 앱 build-for-testing | 통과 | 최종 UI 테스트 앱 빌드 준비, 93fa6959 |

단위 검증 후의 Widget 컨테이너·debug UI fixture·캡처 helper 수정은 위 단위 테스트의 대상 소스를 변경하지 않았다. 실제 파일 해시를 비교한 기록과 원본 로그는 worktree의 `.codex-checks/live-activity-gold/`에 보존한다. 성공한 Settings 캡처와 실패한 시스템 캡처의 상태를 섞지 않는다.

## 수정과 관점별 검토

Security·Data Integrity, SwiftUI·Apple UX의 read-only 검토를 수행하고, Performance·Architecture·Simplicity를 부모가 확인했다. Agent-Native는 최종 PR에 설정·에이전트 지침 변경이 없어 제외한다. 다음 항목은 소스 수정 후 해당 관점에서 확인했다.

- 시간은 시스템 timer Text를 유지하고, 정적 분 문자열로 바꾸지 않는다.
- 설정 갱신은 기존 직렬 큐에 넣고 원래 snapshot 시각과 stale 기준을 보존한다.
- 복구 중 거리를 실제로 복원하지 못하면 지원 여부를 false로 보내 시간으로 전환한다.
- 0과 nil을 구별하며 현재 편집 세트 중량을 전환 시 초기화한다.
- 좁은 값·기호 대체를 포함한 전체 컨테이너의 privacySensitive를 유지한다.
- Gold는 앱 테마와 독립적인 palette를 사용하고 긴 값 앞에서 장식을 제거한다. 축약 화면의 접근성 값에는 원래 정밀도를 보존한다.
- Widget 구성 시 저장소를 읽어 capture하는 대신 ContentState에서 선택값을 읽는다. legacy flat 상태와 새 상태의 roundtrip 테스트를 추가했다.

소스상 신규 P1/P2는 발견되지 않았으나, 아래 UI 실행 게이트는 결과가 확정되기 전까지 완료로 처리하지 않는다.

## UI 실행 경과와 남은 게이트

첫 공통 smoke 실행은 무관한 알림 화면까지 포함해 부모가 중단했다. 통과 증거로 사용하지 않으며 해당 알림 화면은 이번 diff의 원인이 없어 수정하지 않는다.

초기 관련 UI 실행에서 설정 저장 불가와 Widget의 이전 선택 캐시를 발견해 수정했다. 이후 Settings UI는 통과했다. 새 Group 접근성 식별자는 실제로 56×62 장식 심벌에 붙어 카드 밖에 DUNE가 있다는 잘못된 검사가 발생했다. 전체 카드의 실제 native ListCell 경계를 사용하도록 수정했다. 이 진단용 심벌 PNG를 전체 Live Activity 완료 캡처로 게시하지 않는다.

stale 요청을 처음부터 만료된 상태로 시작하면 운동 제목과 Widget ID가 없는 결과가 확인됐다. 정상 요청 후 15초 뒤 만료되고 실제 시스템 상태 전환을 기다리도록 fixture를 수정했다. 사용자에게 기존 자동 재시도 한도를 설명하고 두 stale 테스트의 추가 1회를 승인받았다.

승인한 실행은 테스트 앱 준비 단계에서 420초 deadline으로 중단됐다. `Test Case`와 `Test Suite` 시작은 0건이며 마지막 링크·메타데이터·Prune 뒤 `BUILD INTERRUPTED`다. 이는 stale assertion 실패나 UI 통과의 증거가 아니다. 빌드 의존성을 먼저 확인하며, 실제 stale 검증 결과가 있기 전에는 UI/Pre-Ship/Ship 게이트를 통과시키지 않는다.

원본 SpringBoard 계층에는 다른 앱 알림이 포함될 수 있으므로 저장소에는 대상 카드 PNG와 필요한 출처만 게시한다. 진단 원본은 로컬 실행 자료에 보존한다.

별도 `build-for-testing`은 성공했다. 이후 표준 실행기의 마지막 실행도 host context 5초·시뮬레이터 조회 30초·로그 무갱신 180초 한도에 걸려 테스트에 진입하지 못했다. 실행된 새 UI testcase는 0건이다. 동일 경로의 추가 자동 실행은 중단한다. UI 환경이 정상적으로 응답하고 실제 testcase가 시작되는 것이 재개 조건이다.

## 파이프라인 판정

Init·Plan·Work와 소스 리뷰·수정·해결 문서는 준비했다. UI gate는 실패이며 Quality의 런타임 확인, Pre-Ship, Ship은 통과하지 않았다. 초안 PR은 코드 검토를 위한 보존본이며 머지하지 않는다. 일반 iPhone S01은 저장·재실행 새 캡처를 반영하고, WLA01의 최종 Gold 화면과 다른 기기 S01을 완료 캡처로 표시하지 않는다.

초안 PR 검토에서 포털 미리보기가 다른 상태의 current flag에 의존하는 P2를 발견해 수정했다. running 자체의 current_layout=true와 captured 상태를 요구하며, 다른 상태만 최신·running 최신·running metadata 없음의 세 문서 fixture로 확인했다. 앱·시뮬레이터는 실행하지 않았다.
