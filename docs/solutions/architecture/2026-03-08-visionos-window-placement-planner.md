---
tags: [visionos, swiftui, window-placement, multi-window, testing, typography]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift
  - DUNETests/VisionWindowPlacementPlannerTests.swift
  - DUNEVision/App/DUNEVisionApp.swift
  - DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift
  - DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift
  - DUNEVision/Presentation/Chart3D/ConditionScatter3DView.swift
  - DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift
  - todos/022-in-progress-p2-vision-ux-polish.md
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
  - docs/solutions/architecture/2026-03-08-visionos-volumetric-ux-polish.md
---

# Solution: visionOS Window Placement Planner

## Problem

`todos/022-in-progress-p2-vision-ux-polish.md`의 잔여 범위였던 `defaultWindowPlacement`와 visionOS typography cleanup이 코드에 아직 반영되지 않아, dashboard multi-window experience가 system default placement에 맡겨져 있었다. 동시에 placement fallback 규칙은 코드로 고정돼 있지 않아 regression이 생겨도 unit test로 감지할 수 없는 상태였다.

### Symptoms

- condition/activity/sleep/body/chart3d window가 relative placement 없이 열려 spatial layout 의도가 코드에 드러나지 않았다.
- main window 또는 anchor window가 없는 상황에서 어떤 fallback을 써야 하는지 테스트 가능한 정책이 없었다.
- DUNEVision 일부 surface에 `.caption`이 남아 있어 Phase 5B의 `.callout` minimum rule이 완전히 닫히지 않았다.

### Root Cause

window placement가 `Scene` closure 안의 runtime concern으로만 남아 있었고, 정책 자체를 표현하는 shared abstraction이 없었다. 이 때문에 app wiring은 간단했지만, 실제 배치 intent와 fallback branch를 순수 로직으로 검증할 수 없었다. typography 역시 5B 이후 남은 잔여 `.caption` 사용처를 별도 마감 배치로 정리하지 못했다.

## Solution

window placement intent를 shared `VisionWindowPlacementPlanner`로 분리하고, `DUNEVisionApp`은 `WindowPlacementContext.windows`의 `WindowProxy`를 찾아 실제 `WindowPlacement`로 변환만 하도록 정리했다. 이와 함께 planner의 main-window fallback / utility-panel fallback을 Swift Testing으로 고정하고, DUNEVision의 잔여 `.caption` 사용을 `.callout`로 상향했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift` | Added pure placement planner | relative placement intent와 fallback branch를 testable policy로 분리하기 위해 |
| `DUNETests/VisionWindowPlacementPlannerTests.swift` | Added 9 Swift Testing cases | main anchor, secondary anchor, utility-panel fallback regression을 고정하기 위해 |
| `DUNEVision/App/DUNEVisionApp.swift` | Wired `.defaultWindowPlacement` for dashboard/chart3d windows | 실제 scene placement가 planner policy를 따르도록 하기 위해 |
| `DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift` | `.caption` → `.callout.weight(.bold)` | visionOS readable minimum을 맞추기 위해 |
| `DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift` | `.caption` → `.callout` | legend/body label 가독성을 맞추기 위해 |
| `DUNEVision/Presentation/Chart3D/ConditionScatter3DView.swift` | `.caption` → `.callout` | chart legend typography를 5B 기준에 맞추기 위해 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | `.caption` → `.callout` | immersive stat pill label readability를 맞추기 위해 |
| `todos/022-in-progress-p2-vision-ux-polish.md` | Updated progress note and checklist | 남은 범위를 manual placement visual verification으로 축소하기 위해 |

### Key Code

```swift
enum VisionWindowPlacementPlanner {
    static let mainWindowID: String? = nil
    static let chart3DWindowID = "chart3d"

    static func relationship(
        for windowID: String,
        existingWindowIDs: Set<String?>
    ) -> VisionWindowPlacementRelationship {
        switch windowID {
        case VisionDashboardWindowKind.condition.windowID:
            guard existingWindowIDs.contains(mainWindowID) else {
                return .utilityPanel
            }
            return .leading(mainWindowID)

        case VisionDashboardWindowKind.sleep.windowID:
            if existingWindowIDs.contains(VisionDashboardWindowKind.condition.windowID) {
                return .below(VisionDashboardWindowKind.condition.windowID)
            }
            guard existingWindowIDs.contains(mainWindowID) else {
                return .utilityPanel
            }
            return .below(mainWindowID)

        default:
            return .utilityPanel
        }
    }
}
```

```swift
.defaultWindowPlacement { _, context in
    makeWindowPlacement(for: VisionDashboardWindowKind.sleep.windowID, context: context)
}
```

## Prevention

scene placement 같은 runtime-only concern도 "정책"과 "framework binding"을 분리하면 훨씬 안전해진다. 앞으로 visionOS에서 새 window를 추가할 때는 placement decision을 먼저 pure helper로 정의하고, app layer는 `WindowProxy` lookup과 fallback 적용만 맡긴다.

### Checklist Addition

- [ ] visionOS `WindowGroup`를 추가할 때 relative placement intent를 pure helper로 먼저 분리한다.
- [ ] placement helper는 main anchor 부재 / secondary anchor 부재 / unknown window fallback까지 Swift Testing으로 고정한다.
- [ ] shared source에 새 Swift 파일을 추가했으면 `scripts/lib/regen-project.sh`로 xcodeproj를 재생성한 뒤 build/test를 다시 실행한다.
- [ ] visionOS typography cleanup 후 `rg "\.font\(\.caption" DUNEVision`로 잔여 사용처를 확인한다.
- [ ] relative window placement는 build/test 외에 simulator 또는 device에서 실제 spatial arrangement를 한 번 더 확인한다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다. 다만 visionOS window placement 변경에는 "pure planner + app binding + targeted test" 패턴을 기본값으로 삼는 것이 안전하다.

## Lessons Learned

SwiftUI의 `defaultWindowPlacement`는 API 자체보다도 anchor/fallback policy를 어떻게 표현하느냐가 더 중요했다. placement 규칙을 app file에 직접 누적하면 runtime에서는 동작해도 regression test를 만들기 어렵다. 반대로 policy를 pure helper로 빼면 unit test, app wiring, TODO 문서화가 모두 같은 구조를 바라보게 된다.
