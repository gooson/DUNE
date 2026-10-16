---
tags: [notification, daily-digest, healthkit, cold-start, loading-state, race-condition]
category: general
date: 2026-10-15
severity: minor
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Dashboard/DailyDigestNotificationView.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNEUITests/Full/NotificationRoutingRegressionTests.swift
related_solutions:
  - docs/solutions/general/2026-10-06-notification-digest-checklist-routing.md
---

# Solution: 요약 알림 진입 시 일시적인 데이터 없음 표시 방지

## Problem

### Symptoms

- Today's Summary 알림을 눌러 앱에 들어가면 실제 요약이 나타나기 전에 `No Health Data`가 잠깐 보였다.
- 잠시 뒤 컨디션·수면·걸음 수가 정상적으로 표시됐다.

### Root Cause

앱 시작 시 `canLoadHealthKitData`는 이번 실행의 HealthKit 접근 요청이 끝날 때까지 `false`다. 알림 화면은 이 상태에서도 `DashboardViewModel.loadData(canLoadHealthKitData: false)`를 실행하고 `hasLoaded = true`로 표시했다. 기기에서 HealthKit을 사용할 수 있으면 이 조회는 HealthKit 쿼리와 공유 스냅샷을 건너뛰므로 빈 결과가 된다. 접근 요청이 끝나 새 조회를 하는 동안에도 이전 조회의 `hasLoaded`가 유지되어 빈 상태가 노출됐다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DailyDigestNotificationView.swift` | HealthKit 접근 준비 전에는 로딩 표시를 유지하고 조회를 시작하지 않음 | 빈 임시 결과를 완료된 조회로 오인하지 않기 위해 |
| `DailyDigestNotificationView.swift` | HealthKit을 사용할 수 없는 기기에서는 공유 스냅샷 조회를 허용 | Mac의 기존 미러링 경로를 유지하기 위해 |
| `DailyDigestNotificationView.swift` | 조회 작업이 취소됐으면 `hasLoaded`를 갱신하지 않음 | 준비 상태가 바뀌는 중 오래된 작업의 완료 표시를 막기 위해 |
| `DUNEApp.swift` · `ContentView.swift` · `NotificationHubView.swift` | 권한 요청 실패를 알림 화면에 전달 | 요청 실패 뒤 로딩이 영원히 지속되지 않게 하기 위해 |
| `DUNEApp.swift` | UI 테스트의 권한 준비를 앱 진입부에서 보류하고 백그라운드 복귀 때 해제 | 느린 시뮬레이터에서도 로딩 상태를 확실히 검사하기 위해 |
| `NotificationRoutingRegressionTests.swift` | 준비가 지연된 알림 진입을 재현하고 로딩 → 실제 요약 전환을 검증 | 콜드 스타트 타이밍 회귀를 고정하기 위해 |
| `Localizable.xcstrings` | 권한 요청 실패 안내의 한국어·일본어 번역 추가 | 실패 상태를 사용자 언어로 설명하기 위해 |

### Key Code

```swift
private var isReadyToLoad: Bool {
    canLoadHealthKitData || !HealthKitManager.shared.isAvailable
}

.task(id: isReadyToLoad) {
    guard isReadyToLoad else { return }
    await viewModel.loadData(canLoadHealthKitData: canLoadHealthKitData, forceDailyDigest: true)
    guard !Task.isCancelled else { return }
    hasLoaded = true
}
```

권한 요청에서 오류가 나면 앱이 실패 상태를 전달하고, 알림 화면은 재실행 안내를 표시한다. DEBUG UI 테스트는 `DUNEApp`에서 `canLoadHealthKitData` 신호를 보류한다. 알림 화면의 로딩 상태를 확인한 뒤 앱을 백그라운드로 보냈다가 복귀시키면 준비 신호가 해제된다.

## Prevention

### Checklist Addition

- [ ] 알림이 앱을 시작할 때 권한 준비 신호와 상세 화면의 첫 데이터 조회 순서를 확인한다.
- [ ] `false`가 일시적인 접근 대기 상태라면 이를 조회 완료나 진짜 빈 데이터와 구분한다.
- [ ] HealthKit을 사용할 수 없는 기기의 공유 스냅샷 경로는 권한 준비 신호 없이도 조회할 수 있는지 확인한다.
- [ ] 준비 신호가 바뀔 때 이전 비동기 작업이 완료 상태를 덮지 않는지 테스트한다.
- [ ] 권한 요청이 실패했을 때 로딩이 계속되지 않고 다음 행동을 안내하는지 확인한다.

### Rule Addition

새 공통 규칙은 추가하지 않았다. 동일한 준비 상태 혼동이 다른 알림 화면에서 반복되면 알림 상세 화면의 로딩 상태 규칙으로 승격한다.

## Lessons Learned

알림 라우팅이 올바른 화면으로 이동해도 앱 시작 시 권한 준비와 화면 조회의 순서가 다를 수 있다. 임시로 조회할 수 없는 상태는 실제 데이터가 없는 상태와 별도로 표현해야 한다. 권한 요청 실패도 대기 상태와 구분해야 한다.

## Verification

- iPhone 18 Pro (iOS 27.0) 알림 응답·지연된 HealthKit 준비 UI 테스트: 최종 구현에서 2개 통과, 실패 0개 (`scripts/test-ui.sh --no-regen --simulator-udid 80203360-E4EE-4783-898C-27BB8F7F55B9 --only-testing DUNEUITests/DeferredDigestNotificationRoutingUITests --only-testing DUNEUITests/NotificationResponseRoutingUITests`).
- 권한 실패 처리를 반영한 `scripts/build-ios.sh --no-regen`: `BUILD SUCCEEDED`. 최종 테스트 실행에서도 변경된 앱과 UI 테스트 대상의 빌드가 성공했다.
- T10 실제 화면: 일반 iPhone과 iPad에서 새 캡처를 수집하고 제목·요약·지표 카드의 잘림과 겹침이 없음을 확인했다.
- Duo 접힘·펼침 T10은 이번 변경 후 재캡처하지 못했다. 기존 Duo의 화면 조회가 응답하지 않았고 새 임시 기기는 `Booting` 상태에서 멈췄다. 기존 이미지는 이번 변경의 확인 증거로 사용하지 않는다.
