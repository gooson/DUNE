---
tags: [asyncstream, concurrency, refresh, healthkit, cloudkit, p1]
date: 2026-09-19
category: solution
status: implemented
---

# 새로고침 이벤트를 모든 구독자에게 전달

## Problem

AppRefreshCoordinatorImpl이 만든 단일 AsyncStream을 ContentView와 ScoreRefreshService가 동시에 소비했다. AsyncStream은 이벤트를 모든 iterator에 복제하지 않으므로 점수 서비스가 받은 이벤트가 화면에는 전달되지 않을 수 있었다. 그 결과 캐시는 무효화되지만 화면 refreshSignal은 증가하지 않는 문제가 발생했다.

## Solution

- `AppRefreshCoordinating.makeRefreshStream()`으로 소비자별 독립 구독을 생성한다.
- Coordinator actor가 UUID별 continuation을 보관하고, 캐시 무효화 완료 후 모든 구독자에게 같은 이벤트를 보낸다.
- `onTermination`으로 종료된 구독을 제거한다. 약한 참조를 사용해 구독 정리가 coordinator 수명을 연장하지 않게 한다.
- iOS ContentView, visionOS VisionContentView, ScoreRefreshService가 각각 구독한다.
- 자동 갱신의 기존 throttle, 강제 갱신의 우회 처리, cache-only 무알림 계약은 유지한다.
- 구독 이전 이벤트를 재생하지 않는다. 각 화면의 초기 데이터 로드는 기존 진입 경로에서 수행한다.

## Validation

- 앱 빌드 성공.
- iPhone 17 / iOS 27.0 시뮬레이터에서 AppRefreshCoordinatorTests 및 PersistentStoreRemoteChangeRefreshTests: 22개 테스트, 매개변수별 24회 실행 성공, 실패·스킵 0건.
- 명령: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" -only-testing:DUNETests/AppRefreshCoordinatorTests -only-testing:DUNETests/PersistentStoreRemoteChangeRefreshTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`.
- 회귀 테스트: foreground/HealthKit/CloudKit 이벤트의 두 구독자 전달, 강제 갱신 전달, 구독 취소 격리와 재구독, throttle 및 cache-only의 무알림 동작.
- 기존 stream emission 테스트의 임의 10ms 대기를 제거하고 구독 등록 완료를 await한다. 전달 실패는 테스트 helper의 제한 시간 안에 assertion으로 보고한다.

## Prevention

- AsyncStream 하나를 여러 소비자의 broadcast 채널로 사용하지 않는다.
- 구독 취소가 다른 소비자에게 영향을 주지 않는지 테스트한다.
- 새 이벤트 소비자를 추가할 때 기존 소비자도 동일 이벤트를 받는지 함께 검증한다.

## Lessons Learned

actor 격리는 데이터 경합을 막지만 이벤트의 다중 구독 전달까지 보장하지 않는다. 이벤트 채널의 전달 의미와 취소 수명은 별도로 설계해야 한다.
