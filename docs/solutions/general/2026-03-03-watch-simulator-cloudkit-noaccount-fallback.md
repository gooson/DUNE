---
tags: [watchos, swiftdata, cloudkit, simulator, healthkit, workout, info-plist]
category: general
date: 2026-03-03
severity: important
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift
  - DUNEWatch/DUNEWatchApp.swift
  - DUNEWatch/Resources/Info.plist
  - docs/plans/2026-03-03-watch-simulator-cloudkit-noaccount-fallback.md
related_solutions:
  - docs/solutions/general/2026-02-28-cloudkit-remote-notification-background-mode.md
  - docs/solutions/general/2026-03-02-run-review-fix-batch.md
---

# Solution: Watch Simulator CloudKit No-Account Fallback

## Problem

워치 시뮬레이터에서 운동 시작 시 실패 알럿이 반복되고, 콘솔에 CloudKit 초기화 오류가 다량 출력되었다.

### Symptoms

- 콘솔 경고: `BUG IN CLIENT OF CLOUDKIT: CloudKit push notifications require the 'remote-notification' background mode in your info plist.`
- 콘솔 오류: `Unable to initialize without an iCloud account (CKAccountStatusNoAccount)`
- 사용자 증상: 근력/카디오 모두 운동 시작 실패

### Root Cause

1. 워치 앱의 `ModelConfiguration`이 CloudKit을 항상 `.automatic`으로 강제하고 있어, 시뮬레이터/무계정 환경에서도 CloudKit mirror setup을 시도했다.
2. 워치 Info.plist에 CloudKit push 요구사항(`remote-notification`)과 workout 실행 요구사항(`workout-processing`) background mode가 명시되지 않았다.

## Solution

시뮬레이터/무계정 환경에서는 CloudKit을 비활성화하고, 워치 Info.plist background mode를 보강했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/DUNEWatchApp.swift` | CloudKit 사용 여부를 환경 기반으로 게이팅 (`simulator`는 OFF, 실기기는 iCloud 계정 토큰 기반) | `CKAccountStatusNoAccount` 초기화 실패 경로 차단 |
| `DUNEWatch/Resources/Info.plist` | `UIBackgroundModes: remote-notification` 추가 | CloudKit push 요구사항 충족 |
| `DUNEWatch/Resources/Info.plist` | `WKBackgroundModes: workout-processing` 추가 | 워크아웃 세션 백그라운드 처리 요구사항 충족 |
| `DUNEWatch/Managers/WorkoutManager.swift` | watch simulator에서 HealthKit authorization/session을 우회하는 simulated session fallback 추가 | 시뮬레이터에서 운동 시작 버튼이 전부 실패하는 상태 해소 |
| `DUNEWatch/WatchConnectivityManager.swift` | UI 테스트 실행 시 fixture exercise library 주입 | watch UI 테스트를 iPhone 동기화 상태와 무관하게 안정화 |
| `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift` | `Start` 탭까지 포함한 운동 시작 smoke 테스트 추가 | "실행은 되지만 시작이 안 되는" 회귀를 자동 탐지 |

### Key Code

```swift
private static var shouldEnableCloudKit: Bool {
#if targetEnvironment(simulator)
    logger.info("CloudKit disabled on watch simulator")
    return false
#else
    // Watch has no user-facing cloud sync toggle yet, so gate by account availability.
    let hasICloudAccount = FileManager.default.ubiquityIdentityToken != nil
    if !hasICloudAccount {
        logger.info("CloudKit disabled on watch app due to missing iCloud account")
    }
    return hasICloudAccount
#endif
}

let config = ModelConfiguration(
    cloudKitDatabase: Self.shouldEnableCloudKit ? .automatic : .none
)
```

## Prevention

### Checklist Addition

- [ ] watchOS target에서 CloudKit 사용 시 `UIBackgroundModes: remote-notification` 존재 여부 확인
- [ ] watch workout 앱에서 `WKBackgroundModes: workout-processing` 존재 여부 확인
- [ ] 시뮬레이터에서 CloudKit no-account 로그 발생 시 CloudKit 게이팅 로직 우선 점검
- [ ] watch simulator 검증은 반드시 `Start` 탭까지 포함한 UI smoke 테스트로 확인

### Rule Addition (if applicable)

기존 규칙(`swiftdata-cloudkit.md`, `documentation-standards.md`) 범위 내에서 해결 가능하여 신규 룰 파일 추가는 생략.

## Lessons Learned

- iOS와 동일하게 watch도 CloudKit을 “환경/계정 가용성 기반”으로 게이팅해야 simulator 디버깅 안정성이 유지된다.
- 운동 시작 실패 로그에 CloudKit 경고가 섞이면 원인 파악이 어려워지므로, CloudKit 경고를 먼저 제거해 신호 대 잡음을 높이는 것이 효과적이다.
