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
5. Watch는 운동 중 전송 오류가 발생하면 5초 뒤 미러링을 다시 시작한다. 실패가 반복되면 대기 시간을 두 배씩 늘려 최대 2분 간격으로 재시도한다. 예약 중 iPhone이 다시 연결되면 바로 시도하고, 전송 성공이나 세션 정리 시 간격을 초기화한다.
6. 별도 운동 attributes와 위젯을 등록해 기존 휴식 액티비티를 유지한다. 마지막 Watch 표본에서 5분이 지나면 수치를 숨기고 연결 대기를 표시한다. 정지 시 타이머를 고정하고 compact/minimal에 정지 아이콘을 쓴다.

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
- 연결 오류, 중복 오류, 연속 실패 시 대기 상한, 실제 재연결을 별도 상태로 테스트한다. Swift Testing 매크로 안에서 mutating 호출을 하지 않고 먼저 결과를 계산한다.
- 정지·진행 시스템 타이머의 표시 폭과 정렬을 실제 캡처에서 비교한다. 캡처는 현재 구현과 일치시킨다.

## Lessons Learned

레이아웃에 Watch 지원이 있어도 Watch 운동이 iPhone 표시를 생성하는 것은 아니다. 시작 경로·백그라운드 권한·갱신 전송을 모두 연결해야 한다. 이번 패턴은 기능 구현에 한정되므로 공통 `.claude` 규칙이나 handbook은 변경하지 않았다. 연계된 기존 TODO는 없어 상태를 이동한 파일도 없다.

## 2026-10-25 표시 개선

운동명과 시간이 같은 크기이고 모든 지표가 같은 색으로 나열되어 읽는 순서가 불분명한 문제를 개선했다. Watch 운동 Live Activity에 작은 운동명·상태 헤더, 큰 rounded 경과 시간, 의미별 색상 아이콘과 구분한 숫자·단위를 배치했다. `ViewThatFits`는 지표 행이 들어가지 않으면 세로로 전환한다. small family는 운동명·시간·핵심 지표만 남기고, Dynamic Island의 제한된 폭에서는 시간 글자를 생략한다. 근력·유산소에 공통인 snapshot에 없는 운동 종류를 이름으로 추측하지 않고 중립적인 사람 기호를 사용한다.

전송·타이머·수치 검증 모델은 변경하지 않았다. stale에서는 시간과 수치를 숨기고 정지·종료에서는 누적 시간을 고정하는 기존 계약을 유지한다. 운동명과 수치의 민감 정보 가림도 유지한다. `WatchWorkoutActivityPreview`의 DEBUG 이름 인자와 시스템 UI 테스트로 긴 한국어 근력 운동명을 검증할 수 있게 했다. 실제 시스템 언어는 앱의 launch locale과 별개이므로 상태 검사는 카탈로그의 en·ko·ja 번역을 사용한다.

표시 기준은 [WLA01 레이아웃 맵](../../design/layout-map/watch-workout-live-activity.md), 최신 실제 캡처·기기·검증 범위는 [WLA01 실제 화면맵](../../design/phone-design-map/actual/live-activity/index.html)에 기록한다. 레이아웃 변화가 테마 색·배경·움직임의 변경으로 확대되지 않게 기존 named color를 사용했다. 시스템 시드 캡처는 실제 Watch↔iPhone 운동 연동의 증거와 구분한다.

최종 검증: `.xcodebuild/live-activity-build-final.log`의 통합 iOS·embedded Watch·Widget 빌드 통과, Swift 구문·xcstrings 포맷·diff 공백 검사 통과. 시스템 UI 로그는 4건 중 3건 통과·연결 대기 1건 실패이며 Xcode 결과 정리가 멈춰 실행기 exit 124다. 메서드 통과만으로 UI 게이트 완료를 선언하지 않는다. 세 원본 시스템 PNG와 SHA-256은 실제 화면맵에 보존했다. 연결 대기 fixture 수정, 큰 글씨·밝은 표면·small·Island·iPad·Duo 및 실제 쌍 기기 연동은 미검증이다.

브랜드 식별 보완: 운동 정보만으로 DUNE임을 알아보기 어렵다는 피드백에 따라 공통 헤더의 상태 행을 `DUNE · 운동` 형태로 바꿨다. 번역하지 않는 작은 bold rounded 워드마크에 자간과 기존 액센트를 적용하며 카드 행·높이를 늘리지 않는다. UI 테스트에 브랜드 이름·식별자·포함 프레임 검사를 추가했다. 이전 실제 PNG는 모두 워드마크 추가 전으로 표시했다. SDK 결과 정리 문제의 정상화가 확인되지 않아 후속 UI 실행과 새 캡처는 보류했으며, 빌드 결과는 `.xcodebuild/live-activity-brand-build.log`에 기록한다.

2026-10-25 Watch 종료 후 `연결 대기`가 남는 경로를 보완했다. 취소되는 최종 미러 패킷에 의존하지 않고 WC terminal snapshot을 ActivityKit end에 연결한다. 정확한 Watch 시작 시각·lifecycle 순서·초기 identity 보류·cold orphan 정리와 검증 한계는 [종료 정리 해결 문서](../general/2026-10-25-watch-workout-ended-live-activity-cleanup.md)를 따른다.

## 2026-11-21 운동 중 백그라운드 갱신 지연

운동 중 iPhone을 잠그면 카드가 연결 대기로 바뀌고 앱을 열면 다시 갱신되는 사례가 있었다. Watch가 5초마다 보내더라도 iOS가 일시 정지되면 HealthKit은 여러 분의 데이터를 모아서 전달할 수 있다. 종전 30초 만료 시간은 정상적인 전달 지연에도 연결 대기를 표시했다. [Apple의 백그라운드 운동 데이터 전달 설명](https://developer.apple.com/documentation/healthkit/hkworkoutsessiondelegate/workoutsession%28_%3Adidreceivedatafromremoteworkoutsession%3A%29)

카드 생성과 갱신은 같은 만료 계산을 사용한다. 5분은 앱이 선택한 유예 시간이며 Watch의 표본 시각을 기준으로 계산한다. 미러를 다시 붙일 때 생성한 임시 상태보다 먼저 측정된 표본도 같은 운동의 첫 Watch 데이터이면 반영한다. 워치 표본은 측정 시각 순서로 적용하고, 표본보다 뒤에 관측한 일시 정지·재개는 순서대로 타이머에 반영한다. 심박수 등 수치의 표시 기한은 원래 표본 시각을 기준으로 한다. 실제 전송 오류가 이어지면 위의 재시도 정책을 적용한다.

전용 iPhone 시뮬레이터에서 iPhone·Watch·Widget 타깃을 빌드하고 `WatchWorkoutActivityTests`와 `WorkoutMirrorRetryPolicyTests` 27건이 통과했다. 잠긴 실물 iPhone과 Watch에서의 백그라운드 전달 간격과 프로세스 종료 후 복구는 미검증이다.
