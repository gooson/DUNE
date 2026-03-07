---
tags: [visionos, swiftdata, cloudkit, mirror, opt-in, shared-presentation, spatial-fallback, review-fix]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNEVision/App/DUNEVisionApp.swift
  - DUNE/project.yml
  - DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift
  - DUNE/Presentation/Vision/VisionSpatialSceneKind.swift
  - DUNE/Presentation/Vision/VisionSpatialViewModel.swift
  - DUNEVision/Presentation/Volumetric/VisionSpatialSceneSupport.swift
  - DUNETests/HealthSnapshotMirrorContainerFactoryTests.swift
  - DUNETests/VisionSpatialViewModelTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-03-macos-healthkit-cloud-mirror-foundation.md
  - docs/solutions/general/2026-03-03-watch-simulator-cloudkit-noaccount-fallback.md
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
  - docs/solutions/architecture/2026-03-07-vision-pro-immersive-space-phase3.md
---

# Solution: visionOS Mirror Sync Gating and Spatial Fallback

## Problem

review에서 visionOS mirror fallback 경로에 세 가지 구조 문제가 동시에 드러났다. CloudKit mirror reader가 iOS 앱의 cloud sync opt-in 계약을 우회했고, volumetric spatial scene은 HealthKit unavailable 시점에 곧바로 `.unavailable`로 끝나 새 mirrored snapshot 경로를 전혀 사용하지 못했다. 동시에 `DUNEVision` target은 실제 필요보다 넓은 SwiftData schema/migration 집합을 끌어와 startup coupling을 키우고 있었다.

### Symptoms

- 사용자가 iOS에서 cloud sync를 꺼도 visionOS app은 CloudKit mirror container를 계속 초기화했다.
- dashboard/immersive 쪽은 mirrored snapshot fallback을 사용할 수 있었지만, `spatial-volume` window는 여전히 "Health data isn't available" 상태로 멈췄다.
- visionOS target이 전체 persistence model/migration source를 포함해 unrelated schema 변경에도 startup/build 영향 범위가 넓어졌다.
- `VisionSpatialViewModel`이 `DUNEVision` 전용 경로에 있어 `DUNETests`에서 직접 회귀 테스트를 쓰기 어려웠다.

### Root Cause

1. `DUNEVisionApp`이 mirror reader용 `ModelContainer`를 앱 시작 시 무조건 생성하고, `cloudKitDatabase: .automatic` 경로를 user opt-in과 분리해 다뤘다.
2. volumetric spatial loader가 "HealthKit 없음"을 terminal state로 취급해, 이미 주입된 `SharedHealthDataService` fallback을 평가하기 전에 반환했다.
3. mirror reader에 필요한 것은 `HealthSnapshotMirrorRecord` 하나였지만, target wiring이 전체 persistence 폴더 단위라 schema/migration coupling이 과도했다.
4. spatial orchestration이 visionOS target 내부에 머물러 shared source/test boundary 패턴을 따르지 못했다.

## Solution

mirror consumer를 iOS의 opt-in 계약에 맞춰 다시 설계했다. `HealthSnapshotMirrorContainerFactory`를 도입해 mirror-only schema와 store URL을 별도로 관리하고, `DUNEVisionApp`은 `HealthKit`이 없고 `isCloudSyncEnabled`가 켜진 경우에만 mirror container를 생성한다. sync가 꺼진 경우에는 빈 snapshot service를 주입해 정책을 명시적으로 유지한다.

spatial fallback은 `VisionSpatialViewModel`을 shared `DUNE/Presentation/Vision`으로 옮기면서 함께 정리했다. 이제 view model은 `HealthKit` 부재 자체가 아니라 "HealthKit도 없고 shared snapshot service도 없는 경우"에만 `.unavailable`을 반환한다. mirror-only fallback을 regression test로 고정하기 위해 `VisionSpatialViewModelTests`를 추가했고, `VisionSpatialSceneKind`도 shared source로 분리해 shared orchestration이 target-local enum에 묶이지 않도록 했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEVision/App/DUNEVisionApp.swift` | Cloud sync opt-in을 읽어 mirror service 생성 경로를 조건부로 분리 | visionOS가 iOS의 sync consent 계약을 우회하지 않도록 하기 위해 |
| `DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift` | mirror-only schema/container factory 추가 | visionOS mirror reader가 전체 app schema 대신 필요한 모델만 사용하게 하기 위해 |
| `DUNE/project.yml` | `DUNEVision` target persistence source를 mirror record + recovery helper로 축소 | startup/build coupling을 최소화하기 위해 |
| `DUNE/Presentation/Vision/VisionSpatialViewModel.swift` | spatial loader를 shared source로 이동하고 fallback 조건 수정 | mirrored snapshot 경로를 volumetric scene에서도 재사용하고 테스트 가능하게 만들기 위해 |
| `DUNE/Presentation/Vision/VisionSpatialSceneKind.swift` | spatial scene enum을 shared source로 분리 | shared view model이 visionOS 전용 파일에 의존하지 않게 하기 위해 |
| `DUNEVision/Presentation/Volumetric/VisionSpatialSceneSupport.swift` | shared enum 사용으로 정리 | volumetric UI는 유지하면서 shared orchestration만 분리하기 위해 |
| `DUNETests/VisionSpatialViewModelTests.swift` | HealthKit unavailable + mirrored snapshot fallback 회귀 테스트 추가 | spatial volume이 다시 early return으로 끊기지 않도록 하기 위해 |
| `DUNETests/HealthSnapshotMirrorContainerFactoryTests.swift` | CloudKit gating / mirror-only in-memory container 테스트 추가 | factory contract와 schema 범위를 고정하기 위해 |

### Key Code

```swift
let cloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")

if healthKitAvailable {
    sharedService = SharedHealthDataServiceImpl(healthKitManager: .shared)
} else if cloudSyncEnabled {
    sharedService = Self.makeMirroredSnapshotService(
        cloudSyncEnabled: cloudSyncEnabled
    )
} else {
    sharedService = VisionUnavailableSharedHealthDataService()
}

let healthKitAvailable = healthKitManager.isAvailable
guard healthKitAvailable || sharedHealthDataService != nil else {
    loadState = .unavailable(String(localized: "Health data isn't available in this environment."))
    return
}
```

## Prevention

visionOS/macOS/watch 같은 secondary CloudKit consumer는 "reader니까 괜찮다"는 이유로 iOS app의 sync 정책을 따로 해석하면 안 된다. user opt-in, schema scope, fallback state machine을 primary app과 같은 계약으로 맞춰야 한다. 또한 spatial/immersive orchestration이 target 내부에만 머물면 review fix를 테스트로 고정하기 어렵기 때문에, shared loader/view model 패턴을 우선 적용하는 편이 안전하다.

### Checklist Addition

- [ ] non-primary CloudKit consumer도 `isCloudSyncEnabled` 같은 사용자 opt-in 계약을 그대로 따른다.
- [ ] HealthKit unavailable fallback이 있는 scene/view model은 early return 전에 shared snapshot service 존재를 먼저 평가한다.
- [ ] visionOS target의 persistence wiring은 폴더 단위가 아니라 실제 필요한 schema 파일 단위로 제한한다.
- [ ] spatial/immersive orchestration이 review fix 대상이면 shared source로 올려 `DUNETests`에서 직접 검증한다.
- [ ] `project.yml` 변경 후 `scripts/lib/regen-project.sh`와 `xcodebuild -scheme DUNEVision -destination 'generic/platform=visionOS' build`를 같은 배치에서 검증한다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다. 대신 active correction에 "secondary CloudKit consumer도 opt-in gate를 우회하지 않는다" 항목을 남겨 같은 실수를 다시 막는다.

## Lessons Learned

이번 리뷰 이슈는 서로 다른 세 건처럼 보였지만, 실제로는 "visionOS consumer가 shared contract 바깥에서 독자적으로 자랐다"는 한 가지 문제에 가까웠다. mirror fallback을 붙일 때는 reader path 자체보다 policy parity, schema scope, shared testability를 먼저 맞춰야 이후 surface 확장에서도 같은 비용을 반복하지 않는다.
