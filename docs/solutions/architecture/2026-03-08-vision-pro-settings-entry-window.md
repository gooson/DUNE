---
tags: [visionos, settings, swiftui, windowgroup, openwindow, utility-panel]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNEVision/Presentation/Settings/VisionSettingsView.swift
  - DUNEVision/Presentation/Dashboard/VisionDashboardView.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNEVision/App/DUNEVisionApp.swift
  - DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift
  - DUNETests/VisionWindowPlacementPlannerTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
  - docs/solutions/architecture/2026-03-08-visionos-window-placement-planner.md
---

# Solution: Vision Pro Settings Entry Window

## Problem

Vision Pro 앱의 Today surface에는 immersive, volumetric, chart, dashboard window 진입점은 있었지만 settings 진입점이 없었다. 사용자는 toolbar에서 설정 버튼을 찾을 수 없었고, 실제로 `DUNEVision` target 안에는 열 수 있는 visionOS 전용 settings surface도 없었다.

### Symptoms

- Vision Pro Today 화면에서 settings button이 보이지 않았다.
- iOS에는 `SettingsView`가 있지만, visionOS app에서는 바로 재사용할 수 없었다.
- settings surface를 추가하더라도 runtime rebuild가 없는 토글을 그대로 노출하면, 사용자가 눌러도 즉시 반영되지 않는 broken control이 생길 수 있었다.

### Root Cause

visionOS app 구조가 multi-window dashboard 중심으로 확장되어 왔지만, settings는 scene graph에 포함되지 않았다. 동시에 iOS `SettingsView`는 target 범위와 runtime behavior가 달라서 그대로 공유하기 어렵고, 특히 cloud sync처럼 app runtime 재구성이 필요한 항목은 visionOS 쪽에 동등한 rebuild 경로가 아직 없었다.

## Solution

Today toolbar에 settings gear button을 추가하고, 이 버튼이 dedicated visionOS settings utility window를 열도록 연결했다. settings view는 `DUNEVision` target 안에 전용 `VisionSettingsView`로 두고, 현재 visionOS runtime에서 실제로 동작하는 항목만 노출했다. 또한 multi-window placement planner에 settings window policy를 명시하고 test로 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEVision/Presentation/Settings/VisionSettingsView.swift` | Added visionOS-native settings surface | iOS `SettingsView`를 억지로 공유하지 않고 target-safe한 설정 화면을 제공하기 위해 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | Added toolbar gear button | Vision Pro Today에서 settings discoverability를 확보하기 위해 |
| `DUNEVision/App/VisionContentView.swift` | Wired `onOpenSettings` and fallback push navigation | multi-window 환경에서는 utility window를, 단일-window fallback에서는 in-stack navigation을 사용하기 위해 |
| `DUNEVision/App/DUNEVisionApp.swift` | Added settings `WindowGroup` | settings를 visionOS scene graph의 정식 window로 노출하기 위해 |
| `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift` | Added `settingsWindowID` utility-panel policy | settings window placement intent를 코드로 명시하고 회귀를 막기 위해 |
| `DUNETests/VisionWindowPlacementPlannerTests.swift` | Added settings placement test | settings window가 항상 utility panel로 열리는 정책을 고정하기 위해 |
| `docs/plans/2026-03-08-vision-pro-settings-entry.md` | Recorded plan and final implemented status | 작업 의도와 검증 범위를 남기기 위해 |

### Key Code

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button(action: onOpenSettings) {
        Image(systemName: "gearshape")
    }
    .accessibilityLabel("Settings")
}
```

```swift
if supportsMultipleWindows {
    scheduleWindowOpen(VisionWindowPlacementPlanner.settingsWindowID)
} else {
    showSettings = true
}
```

```swift
case settingsWindowID:
    return .utilityPanel
```

## Prevention

visionOS에 auxiliary surface를 추가할 때는 기존 `openWindow`/`WindowGroup`/placement planner 패턴을 따르는 편이 안전하다. 또한 다른 target에 존재하는 설정 UI를 그대로 복사하기보다, 현재 target에서 runtime까지 실제로 동작하는 control만 surface에 올려야 한다.

### Checklist Addition

- [ ] visionOS에서 새 utility/settings surface를 추가할 때 toolbar entry + `WindowGroup` + placement test를 같은 배치에서 함께 넣는다.
- [ ] 다른 target의 설정 control을 재사용할 때는 해당 control이 현재 target에서도 runtime 재구성을 갖는지 먼저 확인한다.
- [ ] runtime rebuild가 없는 preference는 interactive toggle로 노출하지 않고, 실제 동작 경로가 준비된 뒤 surface에 올린다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다. 다만 visionOS settings 성격의 보조 surface는 "dedicated window + placement policy + tested fallback" 패턴으로 처리하는 편이 안전하다.

## Lessons Learned

visionOS에서는 settings도 단순 push destination보다 scene-level utility window로 붙이는 편이 기존 spatial workflow와 더 잘 맞는다. 반대로 iOS에서 존재하는 toggle이라고 해서 visionOS에도 바로 노출하면 안 된다. user-facing control은 저장만 되는지, 아니면 현재 runtime까지 실제로 갱신되는지까지 확인한 뒤 surface에 올려야 한다.
