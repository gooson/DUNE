---
tags: [visionos, e2e, accessibility, activity, testing]
category: testing
date: 2026-03-09
severity: minor
related_files:
  - DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift
  - DUNEVision/Presentation/Activity/VisionTrainView.swift
  - DUNETests/VisionSurfaceAccessibilityTests.swift
  - todos/086-done-p3-e2e-dunevision-train-view.md
  - todos/021-ready-p2-e2e-phase0-page-backlog-index.md
related_solutions:
  - docs/solutions/testing/2026-03-09-vision-content-surface-e2e-inventory.md
  - docs/solutions/testing/2026-03-09-vision-dashboard-surface-inventory.md
---

# Solution: VisionTrain Surface Inventory

## Problem

`todos/086-ready-p3-e2e-dunevision-train-view.md`는 존재했지만, 실제 `VisionTrainView`에는 root/state/card selector inventory가 거의 없어 deferred visionOS E2E backlog를 코드 기준으로 닫을 수 없었다.

### Symptoms

- visionOS `Activity` lane 안에서 `VisionTrainView` 자체를 가리키는 stable root AXID가 없었다.
- ready 상태의 핵심 카드(SharePlay, Voice Quick Entry, Exercise Form Guide, Spatial Muscle Map)를 selector로 구분할 수 없었다.
- loading / unavailable / failed 상태를 문서 기준으로만 알고 있었고, 실제 view에 고정된 assertion anchor가 없었다.

### Root Cause

이전 batch에서 content/dashboard/chart3d surface까지만 selector helper가 확장됐고, Train surface는 같은 helper/test/TODO sync 패턴으로 정리되지 않은 채 남아 있었다.

## Solution

shared `VisionSurfaceAccessibility` helper에 Train surface 전용 selector를 추가하고, `VisionTrainView`의 root/hero/button/state/card anchor를 wiring했다. 이후 stability test와 TODO 문서를 같은 vocabulary로 갱신해 surface inventory drift를 줄였다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | Added Train root/state/card/button identifiers | selector naming을 한 곳에서 관리하기 위해 |
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | Wired AXID to root, hero, chart button, state containers, ready cards | root surface assertion anchor를 실제 view에 고정하기 위해 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | Added Train stability/uniqueness test | helper mapping drift를 빠르게 감지하기 위해 |
| `todos/086-done-p3-e2e-dunevision-train-view.md` | Filled entry route, selector inventory, assertion scope, deferred lanes | backlog 문서와 코드 기준을 동기화하기 위해 |
| `todos/021-ready-p2-e2e-phase0-page-backlog-index.md` | Updated 086 link to done filename | backlog 탐색 시 현재 상태를 정확히 반영하기 위해 |

### Key Code

```swift
enum VisionSurfaceAccessibility {
    static let trainRoot = "vision-train-root"
    static let trainHeroCard = "vision-train-hero-card"
    static let trainOpenChart3DButton = "vision-train-open-chart3d-button"
    static let trainSharePlayCard = "vision-train-shareplay-card"
}
```

```swift
ScrollView {
    ...
}
.accessibilityIdentifier(VisionSurfaceAccessibility.trainRoot)
```

## Prevention

visionOS surface TODO를 닫을 때는 card 내부 interaction까지 한 번에 욕심내지 말고, 우선 root/state/card selector inventory를 공용 helper에 고정한 뒤 TODO와 테스트를 같이 맞춘다.

### Checklist Addition

- [ ] visionOS surface가 여러 `loadState`를 가지면 각 상태별 container AXID를 별도로 둘 것
- [ ] root surface TODO를 닫을 때는 hero/action button 존재 여부와 deep interaction assertion 범위를 분리할 것
- [ ] TODO를 `done`으로 바꿀 때 backlog index 링크도 함께 동기화할 것

### Rule Addition (if applicable)

새 rule 파일 추가는 보류했다. 다만 후속 `087/089/090` 같은 deferred visionOS surface도 같은 `helper + view wiring + selector test + TODO sync` 패턴으로 처리하는 편이 안전하다.

## Lessons Learned

Vision Pro backlog의 “next TODO”를 고를 때는 broad epic보다 바로 닫을 수 있는 surface inventory 작업을 먼저 처리하는 편이 효율적이다. 특히 Train처럼 여러 child card를 품는 root surface는 내부 interaction을 다 자동화하려고 하기보다, root/state/card anchor를 먼저 고정해 두면 이후 전용 automation TODO로 자연스럽게 분기할 수 있다.
