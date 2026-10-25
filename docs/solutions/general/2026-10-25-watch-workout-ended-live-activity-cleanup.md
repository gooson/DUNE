---
tags: [watchos, activitykit, watchconnectivity, workout-mirroring, lifecycle, concurrency]
date: 2026-10-25
category: solution
status: implemented
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNE/Presentation/Exercise/WatchWorkoutActivity.swift
  - DUNE/Presentation/Exercise/WatchWorkoutMirrorManager.swift
  - Shared/WatchWorkoutSnapshot.swift
---

# Watch에서 종료한 운동의 Live Activity 정리

## Problem

Watch에서 운동을 종료해도 iPhone의 체스트 프레스 머신 Live Activity가 `Watch 연결 대기`로 남았다. `enqueueMirrorSnapshot()`은 MainActor Task로 종료 패킷을 예약하는데, 같은 동기 종료 경로의 `stopMirrorTransport()`가 즉시 Task를 취소하고 pending 패킷을 지웠다. 별도 WatchConnectivity context의 `watchWorkoutActive=false`는 iPhone의 내부 상태만 바꾸고 ActivityKit 정리로 연결되지 않았다.

HealthKit의 `end()`는 SDK 계약상 미러링도 자동 종료한다. 따라서 취소되는 최종 데이터 전송을 성공으로 간주하거나 `end()` 뒤 불필요한 미러 중지 호출을 반복해서는 안 된다. 실제 사진은 종료 데이터가 정리 경로까지 도달하지 않았음을 보여 주지만, 실기기의 delegate 전달 순서를 시뮬레이터에서 재현한 증거는 아니다.

## Solution

| 변경 | 목적 |
|---|---|
| Watch 종료 스냅샷을 미러 연결과 독립적으로 생성 | 연결이 끊겼어도 실제 운동 시작·종료 정보를 보존 |
| WC applicationContext의 `watchWorkoutEndedSnapshot`과 연결 중 즉시 메시지 | 지속되는 최신 상태와 빠른 전달을 함께 사용; 영구 전송 큐는 만들지 않음 |
| 다음 운동 시작 시 종료 스냅샷 키 삭제 | 이전 종료 상태가 새 운동에 섞이지 않게 함 |
| iPhone parser의 4,096바이트·JSON·수치·ended 검증 | 손상되거나 다른 상태인 패킷으로 액티비티를 닫지 않음 |
| WatchSessionManager 콜백을 mirror manager의 종료 경로에 연결 | 미러 delegate와 별개로 정리 수행 |
| serial Activity driver와 같은 시작 시각의 orphan ActivityKit 정리 | 실행 중 갱신이 끝난 카드를 되살리는 경합과 앱 재시작 잔여 카드를 처리 |
| 정확한 Watch 시작 시각과 lifecycle timestamp 정렬 | 2초 이내 새 운동·늦은 이전 종료가 새 세션을 닫지 않게 함 |
| 시작 시각 없는 미러는 첫 authoritative 패킷 전까지 카드 생성 보류 | 종료 후 늦게 만들어지는 식별 불가능한 placeholder를 방지 |

첫 authoritative Watch 패킷은 임시 iPhone 시작·갱신 시각을 한 번 보정할 수 있다. 먼저 도착한 종료 스냅샷을 이때 다시 대조해, 이미 끝난 운동이면 새 카드를 만들기 전에 ended로 합친다. 이후에는 기존 timestamp·session guard를 유지한다. 늦은 종료 payload는 과거 orphan을 닫을 수 있도록 전달하되, 오래된 lifecycle timestamp로 현재 active/template 상태를 되돌리지 않는다.

Watch UI와 HealthKit `end()`는 즉시 처리한다. 정기 미러 전송 취소는 최종 패킷을 전달했다는 보장으로 사용하지 않는다. 늦게 완료되는 이전 builder의 최종화·timeout은 새 세션 상태를 바꾸지 않게 세션 참조를 대조한다.

## Verification

- 최종 통합 빌드: `scripts/build-ios.sh --no-regen --log-file .xcodebuild/watch-end-cleanup-verified-build.log`.
- 실제 코어 controller·snapshot·lifecycle ordering·WC parser 소스와 저장소의 관련 테스트 세 파일을 macOS Swift Testing 패키지로 분리해 **35건 통과**. 로그: `.xcodebuild/watch-end-core-tests-final.log`, 입력 SHA-256: `.codex-checks/watch-end-core-tests/source-manifest.json`.
- 이 보조 검증은 ActivityKit/HealthKit/WCSession 시스템 드라이버를 제외하고 테스트의 주입 mock을 사용한다. iOS 앱 전체 unit suite나 실기기·시뮬레이터 연동 통과를 뜻하지 않는다. 표준 unit 실행기는 선택 suite 옵션 없이 전체 unit target을 실행하므로 요청 범위를 넘는 전체 테스트 대신 이 한정된 코어 검증을 사용했다.
- 검증 사례: terminal context 종료, 이전 종료의 새 운동 보호, 1ms·1초 간격의 시작 구분, attach 전 종료, 시작 시각 없는 늦은 attach, 실행 중 update와 end 직렬화, 재등장 방지, 잘못된/큰/비종료 데이터 거부, lifecycle 메시지 역전 방어.
- 세션 구분·초기 identity·lifecycle 순서에 대한 read-only 재검토: 남은 P1/P2 없음.
- 이전 UI 실행은 Xcode SDK 결과 정리에서 멈췄고, 실패 의존성의 정상화가 확인되지 않아 같은 UI 실행을 반복하지 않았다. 실제 Watch→잠긴 iPhone의 종료·연결 끊김·재연결·앱 재시작 경로와 WLA01 종료 후 제거 캡처는 미검증이다. 기존 PNG는 이 수정의 증거로 사용하지 않는다.

## Prevention

- 종료처럼 한 번뿐인 상태는 취소 가능한 주기 전송에만 의존하지 않는다.
- terminal 패킷은 세션 identity로 대조하고, 순서가 뒤집힌 lifecycle 상태와 orphan 정리를 별도로 판단한다.
- 식별 불가능한 초기 시스템 UI를 먼저 만든 뒤 나중에 종료와 연관시킬 수 있다고 가정하지 않는다.
- 코어 mock 검증과 실제 paired-device background delivery 증거를 구분한다.

## Lessons Learned

stale 표시는 데이터 노후화에 대한 UI일 뿐 운동 종료가 아니다. 운동 종료는 독립된 확정 상태로 전달하고 ActivityKit end까지 연결해야 한다. 종료 후 원격 콜백·전송이 끊기는 상황 자체가 마지막 상태를 없애는 이유가 되어서는 안 된다.

## Review Resolve 보완

분리한 `codex/watch-live-activity`의 리뷰에서 단일 종료 스냅샷이 여러 지연 attach를 보호하지 못하는 점을 발견했다. 정확한 시작 시각별 최근 32개 종료 상태를 보존하도록 바꾸고 A 종료→B 종료→A 지연 attach 회귀 테스트를 추가했다. 해당 P2는 재검토에서 Resolved이며 코어 테스트는 36건 통과했다. 새 base에서 통합 빌드도 통과했다. 필수 시스템 UI 결과 정리·최신 워드마크 검증은 여전히 Open이므로 PR과 merge는 보류했다. [최종 리뷰와 재개 조건](../../reviews/2026-10-25-watch-live-activity-review-ship.md)을 따른다.
