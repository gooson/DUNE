---
tags: [watchos, healthkit, activitykit, workout-mirroring, live-activity, background-launch, concurrency]
category: architecture
date: 2026-10-24
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/Presentation/Exercise/WatchWorkoutMirrorManager.swift
  - DUNE/Presentation/Exercise/WatchWorkoutActivity.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNE/Domain/Models/WorkoutMirrorRetryPolicy.swift
  - Shared/WatchWorkoutSnapshot.swift
  - Shared/WatchWorkoutAttributes.swift
  - DUNEWidget/WatchWorkoutLiveActivity.swift
related_solutions:
  - architecture/2026-09-20-iphone-duo-adaptive-experience.md
  - general/2026-10-14-rest-live-activity-layouts.md
---

# Solution: Watch 운동을 iPhone 라이브 액티비티에 연결

## Problem

최근 추가된 라이브 액티비티가 Watch 운동 중에는 나타나지 않았다. 기존 구현은 iPhone `WorkoutSessionView`의 세트 사이 휴식 타이머에만 연결되어 있었고, Watch 공통 운동 시작 경로에는 생성 요청이 없었다. 기존 Watch small family 지원은 iPhone 휴식 표시를 Watch에 전달하는 레이아웃이었다.

### Root Cause

WatchConnectivity의 운동 시작 메시지나 완료 기록 동기화는 iPhone 앱에 백그라운드 라이브 액티비티 시작 권한을 주지 않는다. `HKWorkoutSession` 미러링과 앱 초기화 시의 수신 핸들러가 필요했다.

## Solution

1. Watch의 실제 근력·유산소 공통 시작 경로에서 `startMirroringToCompanionDevice()`를 비동기로 호출한다. 미러링 실패가 운동 기록을 중단하지 않는다.
2. iPhone은 `DUNEApp.init`의 데이터 저장소 초기화보다 먼저 `workoutSessionMirroringStartHandler`를 등록한다. 핸들러의 콜백 큐에서 즉시 라이브 액티비티를 요청한 뒤 MainActor에 세션 관리를 넘긴다. 첫 운동 데이터나 MainActor 초기화를 기다리지 않는다.
3. Watch는 5초 간격 및 정지·재개·운동 변경 시 소형 `WatchWorkoutSnapshot`을 보낸다. 경과 시간은 활성 시간이며, 시스템 타이머가 매초 표시를 갱신하므로 전송 주기를 늘릴 필요가 없다.
4. iPhone은 세션 identity, 업데이트 시각, 시작 시각, 수치 범위를 검증한다. nil 시작 시각의 임시값은 첫 유효한 Watch 패킷만 한 번 보정할 수 있다. ActivityKit 작업을 직렬 처리해 갱신·종료 경합을 방지한다.
5. Watch 장애당 5초 후 한 번만 자동 재시도한다. 재시도 예산은 실제 첫 전송 성공 후 초기화하고, 실패 소진 후에는 실제 WatchConnectivity 연결 해제→연결 이벤트만 재개를 허용한다. 중복 오류가 예약된 재시도를 취소하지 않게 한다.
6. 별도 운동 attributes와 위젯을 등록해 기존 휴식 액티비티를 유지한다. 오래된 상태는 30초 staleDate 뒤 수치를 숨기고 연결 대기를 표시한다. 정지 시 타이머를 고정하고 compact/minimal에 정지 아이콘을 쓴다.

Apple은 [WWDC23 multi-device workout 안내](https://developer.apple.com/videos/play/wwdc2023/10023/)와 [미러링 시작 핸들러 문서](https://developer.apple.com/documentation/healthkit/hkhealthstore/workoutsessionmirroringstarthandler)에서 iPhone 백그라운드 실행과 이 핸들러의 라이브 액티비티 시작 권한을 설명한다. 설치된 SDK의 `HKHealthStore.h`에서도 해당 일회성 권한을 확인했다.

### Changes Made

| 영역 | 변경 | 이유 |
|---|---|---|
| Watch WorkoutManager | 미러링·주기 전송·복구·정리 | 실제 Watch 세션을 시작점으로 연결 |
| 공통 snapshot / retry policy | Codable 검증·활성 시간·제한된 재시도 | UI와 전송 lifecycle 테스트 |
| iPhone mirror manager / activity driver | 조기 요청·세션 수신·직렬 갱신 | 초기 실행 제한과 경합 처리 |
| Widget | 시스템 표면의 진행·정지·stale 표시 | 운동 전체 진행 상태 제공 |
| 디자인맵 | WLA01 시안과 실제 요소 캡처·출처 | 시드 시스템 표시와 실기기 연동 증거 구분 |

## Verification

- `scripts/build-ios.sh`: iPhone·embedded Watch·widget 통합 빌드 통과. 마지막 리뷰 수정 후에도 재빌드 통과.
- 관련 단위 테스트 21개 통과, 실패·스킵 0개: snapshot 검증, 직렬 ActivityKit driver, provisional 시작 시각, 종료 후 재등장 방지, 제한된 재연결 정책.
- iPhone UI: Activity 진입 회귀 2개 및 Live Activity 시스템 표시 2개 통과. 위젯 정렬 변경 후 영향받는 2개를 다시 검증하고 새 캡처로 교체했다.
- [WLA01 실제 요소 캡처](../../design/phone-design-map/actual/live-activity/index.html): iPhone 18 Pro / iOS 27.0, 실제 SpringBoard 알림 센터의 진행·정지 상태. DEBUG 시드이며 다른 앱 알림이 포함되지 않는 원본 XCTest 요소 스크린샷이다. 출처·시각·결과 번들은 `capture-index.json`에 기록했다.
- 시스템 위젯은 앱 launch locale과 달리 SpringBoard의 언어를 사용했다. UI 테스트는 지원 언어의 상태 문구와 최초 실시간 현황 허용 안내를 처리한다.
- 전체 UI suite는 요청되지 않아 실행하지 않았다. Watch 시뮬레이터의 기존 운동 시작은 실제 HealthKit 세션을 우회하므로 이번 전송을 검증하는 증거로 쓰지 않았다.
- 미검증: 실제 DUNE Watch↔잠긴 iPhone의 시작·갱신·복구, Dynamic Island compact/expanded·stale, Watch small, iPad, Duo 접힘/펼침. 해당 WLA01 상태는 캡처 대기이며 기존 PNG를 새 증거로 재사용하지 않았다.

## Prevention

- Watch에서 시작하는 기능은 iPhone에서 먼저 시작해야 하는 기능과 분리해 호출 경로를 확인한다.
- 백그라운드 시작 권한을 얻는 핸들러에서는 첫 데이터나 MainActor 작업을 기다리지 않는다.
- 비동기 콜백의 상태는 actor hop 전에 값으로 캡처한다. 하나의 판단에 쓰는 날짜와 fallback 여부는 같은 읽기에서 결정한다.
- 연결 오류, 중복 오류, 소진된 재시도, 실제 재연결을 별도 상태로 테스트한다. Swift Testing 매크로 안에서 mutating 호출을 하지 않고 먼저 결과를 계산한다.
- 정지·진행 시스템 타이머의 표시 폭과 정렬을 실제 캡처에서 비교한다. 캡처는 현재 구현과 일치시킨다.

## Lessons Learned

레이아웃에 Watch 지원이 있어도 Watch 운동이 iPhone 표시를 생성하는 것은 아니다. 시작 경로·백그라운드 권한·갱신 전송을 모두 연결해야 한다. 이번 패턴은 기능 구현에 한정되므로 공통 `.claude` 규칙이나 handbook은 변경하지 않았다. 연계된 기존 TODO는 없어 상태를 이동한 파일도 없다.
