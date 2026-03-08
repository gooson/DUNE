---
tags: [visionos, e2e, accessibility, backlog, testing]
category: testing
date: 2026-03-09
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift
  - DUNETests/VisionSurfaceAccessibilityTests.swift
  - DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift
  - DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift
  - DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift
  - todos/021-ready-p2-e2e-phase0-page-backlog-index.md
  - todos/087-done-p3-e2e-dunevision-dashboard-window-scene.md
  - todos/089-done-p3-e2e-dunevision-volumetric-experience-view.md
  - todos/090-done-p3-e2e-dunevision-immersive-experience-view.md
related_solutions:
  - docs/solutions/testing/2026-03-09-vision-content-surface-e2e-inventory.md
  - docs/solutions/testing/2026-03-09-vision-dashboard-surface-inventory.md
  - docs/solutions/testing/2026-03-09-vision-train-surface-inventory.md
---

# Solution: Vision Deferred Surface Inventory Batch

## Problem

Vision Pro deferred E2E backlog에서 `087`, `089`, `090`은 아직 ready 상태였고, 실제 코드에는 해당 surface를 가리키는 stable selector inventory가 비어 있었다. 이 상태에서는 나중에 harness가 생겨도 window scene, volumetric window, immersive space에 대한 회귀 자동화를 문서 리서치부터 다시 시작해야 했다.

### Symptoms

- `VisionDashboardWindowScene`, `VisionVolumetricExperienceView`, `VisionImmersiveExperienceView`에 stable AXID anchor가 부족했다.
- ready TODO 문서는 존재했지만 code/test/TODO가 같은 selector vocabulary를 공유하지 못했다.
- backlog index와 상위 done TODO 안에 이미 완료된 surface를 여전히 옛 `ready` 파일명으로 가리키는 stale link가 남아 있었다.

### Root Cause

deferred visionOS surface를 "나중에 자동화할 문서 작업"으로만 취급한 것이 원인이었다. 그 결과 selector policy가 코드에 고정되지 않았고, TODO rename 이후 주변 문서 링크까지 한 배치에서 함께 정리하는 규칙도 약했다.

## Solution

기존 content/dashboard/train inventory 패턴을 그대로 확장해, 이번에는 남은 deferred surface 세 개를 한 묶음으로 정리했다. `VisionSurfaceAccessibility` helper에 새 selector를 추가하고, 실제 DUNEVision surface에 identifier를 연결했으며, shared unit test와 TODO/backlog 문서를 같은 vocabulary로 동시에 갱신했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | Added dashboard-window / volumetric / immersive selector inventory | surface별 AXID drift를 한 곳에서 관리하기 위해 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | Added stability and uniqueness coverage for new selectors | selector 계약을 test로 고정하기 위해 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift` | Wired root/state/hero/detail/message identifiers | dedicated metric window surface를 assert 가능하게 만들기 위해 |
| `DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift` | Wired root/state/ornament/scene identifiers | volumetric surface를 scene 단위로 구분 가능하게 만들기 위해 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | Wired root/header/control/state/action identifiers | immersive control surface 진입 기준을 고정하기 위해 |
| `todos/087-done-*.md`, `todos/089-done-*.md`, `todos/090-done-*.md` | Closed TODOs with real selector inventory | backlog 문서를 코드 기준 source of truth로 맞추기 위해 |
| `todos/021-ready-p2-e2e-phase0-page-backlog-index.md` and related done TODOs | Synced stale filename references | rename 이후 broken backlog links를 막기 위해 |

### Key Code

```swift
enum VisionSurfaceAccessibility {
    static let volumetricRoot = "vision-volumetric-root"
    static let immersiveRoot = "vision-immersive-root"

    static func dashboardWindowRootID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-window-\(kind.rawValue)-root"
    }

    static func volumetricSceneID(for scene: VisionSpatialSceneKind) -> String {
        "vision-volumetric-scene-\(scene.rawValue)"
    }
}
```

```swift
NavigationStack {
    ...
}
.accessibilityIdentifier(VisionSurfaceAccessibility.dashboardWindowRootID(for: kind))
```

## Prevention

visionOS deferred surface TODO를 닫을 때는 selector helper, view wiring, stability test, TODO rename, backlog link sync를 반드시 같은 배치에서 처리한다.

### Checklist Addition

- [ ] deferred visionOS surface를 닫을 때 TODO 문서만 채우지 말고 shared accessibility helper를 먼저 확장할 것
- [ ] selector rename 또는 TODO rename 이후 backlog index와 상위 done TODO의 링크도 같은 commit에서 함께 동기화할 것
- [ ] simulator/harness 미구축 상태라도 root/state/action anchor는 미리 코드에 고정해 둘 것

### Rule Addition (if applicable)

새 rule 파일 추가는 보류했다. 다만 후속 Vision Pro surface도 `helper + view wiring + selector test + TODO sync + backlink cleanup` 패턴을 기본 절차로 삼는 편이 안전하다.

## Lessons Learned

Vision Pro "다음 작업"을 개별 TODO 하나씩 처리하면 문서/selector drift가 다시 쌓인다. 같은 패턴을 공유하는 deferred surface는 묶어서 닫아야 backlog와 코드가 함께 정리되고, 이후 harness 작업이 훨씬 빨라진다.
