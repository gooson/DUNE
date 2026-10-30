---
tags: [activitykit, live-activity, watch, workout, preferences, gold]
category: architecture
date: 2026-10-30
severity: important
related_files:
  - Shared/WorkoutLiveActivityPreferences.swift
  - Shared/WatchWorkoutSnapshot.swift
  - DUNEWidget/WatchWorkoutLiveActivity.swift
  - DUNE/Presentation/Exercise/WatchWorkoutActivity.swift
  - DUNEWatch/Managers/WorkoutManager.swift
related_solutions:
  - architecture/2026-10-30-live-activity-workout-icons.md
  - architecture/2026-10-24-watch-workout-live-activity.md
---

# 운동별 주 지표와 Gold Impact Live Activity

## Problem

음악과 운동이 함께 활성화된 Dynamic Island에서는 운동이 작은 기호로만 보일 수 있다. 시간만 표시하면 러닝 거리나 웨이트 현재 입력 중량을 우선 보고 싶은 사용자의 선호도 반영하지 못한다.

구현 시에는 0과 미수신을 구별해야 한다. 완료한 세트의 중량을 현재 세트 값으로 재사용하거나, Watch 복구 중 복원되지 않은 거리를 0 km로 표시해서는 안 된다. 설정 변경으로 시작한 ActivityKit 갱신이 더 최신 Watch snapshot을 덮어쓰는 순서 역전도 방지해야 한다.

## Solution

| 영역 | 최종 계약 |
|---|---|
| 설정 | 유산소 시간/거리/심박, 근력 시간/현재 세트 중량/심박을 독립 저장한다. 기본 지표는 시간, 스타일은 Gold Impact이며 Standard를 선택할 수 있다. App Group에 접근할 수 없는 환경에서는 앱 표준 저장소에 선택을 보존한다. |
| 전송 | optional workoutKind, supportsDistance, currentSetWeightKg를 추가한다. 구버전/알 수 없는 종류는 안전하게 시간으로 전환한다. |
| 현재 중량 | Watch의 편집 중인 세트 입력만 전송하며 세트·운동 전환 시 초기화한다. 0은 값이고 nil은 미수신이다. |
| 유효성 | 거리 지원과 유한한 범위의 값을 요구한다. 복구 중 실제 거리가 복원되지 않으면 supportsDistance=false로 시간에 대체한다. |
| 갱신 | 설정 변경도 기존 직렬 snapshot 큐에 넣는다. ActivityKit ContentState에 snapshot과 preferences를 함께 담아 Widget 구성 시의 설정 캐시와 동일 상태 갱신에 의존하지 않는다. 원래 updatedAt과 stale 기한을 보존하며 이전 flat 상태도 디코딩한다. |
| 표현 | 잠금 화면에 골드 표면·능선·장식 심벌·큰 주 지표를 사용한다. Island는 시스템 검정 표면을 유지한다. 앱 테마와 독립적인 골드 색을 사용한다. |
| 좁은 폭 | ViewThatFits에서 수치가 들어가지 않으면 지표 기호로 전환한다. 전체 수치는 접근성 값에 유지하며 컨테이너 전체를 privacySensitive로 지정한다. |
| 시간 | 시스템 timer Text를 사용한다. 자동 갱신이 보장되지 않는 정적 분 축약은 사용하지 않는다. |
| 읽기 순서 | 긴 값은 장식 심벌을 먼저 제거한다. 큰 접근성 글씨에서는 장식을 숨긴다. Standard도 시간이 아닌 주 지표에는 보조 시간을 제공한다. |
| 컨테이너 | showsWidgetContainerBackground에 따라 잠금 화면 장식 배경을 적용하며 StandBy에서는 시스템 배경 tint를 사용한다. 테스트 캡처는 제목을 포함한 실제 시스템 ListCell을 찾는다. Group 식별자를 전체 카드의 경계로 사용하지 않는다. |
| 상태 | pause/stale 기호가 운동/지표 기호보다 우선한다. stale은 오래된 수치를 숨기며 종료 시 기존 정책대로 제거한다. |

## Verification

- 93fa6959에서 iOS·Widget·embedded Watch 일반 빌드가 통과했다.
- 관련 네이티브 iOS 4개 suite의 46개와 Watch WorkoutManagerReorderTests 5개가 통과했다. 이후 Widget·UI fixture·캡처 helper 변경에서 이 단위 검증의 대상 소스가 동일한지 비교했다. 전체 프로젝트 테스트 결과가 아니다.
- Settings의 유산소/근력/스타일 독립 저장과 앱 재실행 UI 검증이 통과했다. 초기 Shared macOS harness의 24개 결과는 위 네이티브 검증으로 보완했다.
- 현재 변경 범위의 네이티브 UI는 WatchWorkoutLiveActivityUITests와 LiveActivitySettingsUITests로 한정한다. 첫 공통 smoke 실행은 무관한 알림 화면까지 포함해 부모가 중단했으며 UI 통과로 사용하지 않는다.
- [레이아웃 계약](../../design/layout-map/watch-workout-live-activity.md), [보존 시안](../../design/layout-map/live-activity-size-state-proposal.md), [실제 화면맵](../../design/phone-design-map/actual/live-activity/index.html)을 구분한다. 시안 PNG를 실제 시스템 캡처로 재사용하지 않는다.
- 시스템 카드와 stale 전환의 최종 실행 상태는 [검증 기록](../../reviews/2026-10-30-live-activity-gold-preferences.md)에 기록한다. 이미 만료된 요청은 카드가 생성되지 않을 수 있으므로 stale fixture는 정상 시작 후 짧은 기한이 실제로 만료되는 과정을 사용한다. 테스트에 진입하기 전 빌드 중단은 UI 실패나 UI 통과로 간주하지 않는다.

Apple의 [WWDC26 Live Activities essentials](https://developer.apple.com/videos/play/wwdc2026/223/)에서 설명한 ContentState 갱신, 제한 폭의 대체 표현, small family와 컨테이너 배경 규칙을 대조했다. [Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)의 시스템 표현을 유지한다.

## Prevention

새 지표는 값과 지원 여부를 함께 검증하고, 실제 0을 미수신으로 취급하지 않는다. ActivityKit 갱신 경로를 새로 만들 때는 기존 큐와 stale 기준을 먼저 확인한다. 폭 제한은 ViewThatFits와 전체 접근성 값으로 처리하고, 장식이 핵심 수치를 밀어내지 않게 한다. 테스트 selector는 변경에 영향을 받는 묶음만 명시한다.

## Lessons Learned

브라우저 시안의 축약 시간과 화려한 배치를 그대로 옮기기보다 시스템 timer·표면·접근성·전송 계약을 함께 설계해야 한다. 거리 복구가 불확실할 때는 유효하지 않은 0을 표시하는 대신 이미 검증된 경과 시간으로 전환하는 것이 정확하다.
