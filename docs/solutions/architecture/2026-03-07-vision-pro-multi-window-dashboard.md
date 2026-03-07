---
tags: [visionos, swiftui, windowgroup, openwindow, healthkit, dashboard]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionDashboardWorkspaceViewModel.swift
  - DUNETests/VisionDashboardWorkspaceViewModelTests.swift
  - DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift
  - DUNEVision/App/DUNEVisionApp.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNEVision/Presentation/Dashboard/VisionDashboardView.swift
  - DUNE/project.yml
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-volumetric-phase2.md
---

# Solution: Vision Pro Multi-Window Dashboard

## Problem

Vision Pro roadmap의 E1 Multi-Window Dashboard는 TODO에만 있었고, 실제 앱에서는 `chart3d`, volumetric, immersive space만 따로 열 수 있었다. condition/activity/sleep/body composition을 공간에 각각 배치하는 workflow가 없어, Phase 4가 약속한 shared-space 탐색 경험이 비어 있었다.

### Symptoms

- 메인 visionOS dashboard에서 metric별 독립 window를 열 수 없었다.
- phase 4 구현을 하려면 각 window가 공통 HealthKit/snapshot 데이터를 다시 조합해야 했지만, 이를 위한 shared loader가 없었다.
- visionOS 전용 뷰에 데이터를 직접 붙이면 테스트가 어려워지고, DUNEVision target source wiring까지 쉽게 깨질 수 있었다.

### Root Cause

visionOS scene는 이미 `openWindow(id:)`와 `WindowGroup`로 확장 가능했지만, reusable한 workspace summary 계층이 없어서 각 window를 안전하게 늘릴 구조가 준비되지 않았다. 또한 DUNEVision target은 iOS `Presentation/` 전체를 포함하지 않기 때문에, shared 파일을 새로 만들면 `project.yml` source-of-truth까지 함께 갱신해야 했다.

## Solution

shared `VisionDashboardWorkspaceViewModel`을 `DUNE/Presentation/Vision/`에 추가하고, DUNEVision에서는 그 결과를 렌더링하는 window scene만 얇게 두는 구조로 정리했다. 동시에 condition/activity/sleep/body 전용 `WindowGroup`을 추가해 메인 dashboard에서 각 window를 열 수 있게 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionDashboardWorkspaceViewModel.swift` | Added shared workspace loader and summary models | visionOS window data 조합을 테스트 가능하게 분리 |
| `DUNETests/VisionDashboardWorkspaceViewModelTests.swift` | Added Swift Testing coverage | authorization, partial failure, ready/unavailable state 검증 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift` | Added reusable metric window UI | condition/activity/sleep/body 각 window의 공통 chrome 제공 |
| `DUNEVision/App/DUNEVisionApp.swift` | Added four dashboard `WindowGroup`s | E1 multi-window surface 실제 노출 |
| `DUNEVision/App/VisionContentView.swift` | Wired dashboard open actions | 메인 scene에서 새 windows 호출 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | Replaced disabled placeholders with window launch cards | dashboard에서 multi-window entry 제공 |
| `DUNE/project.yml` | Added `Presentation/Vision` to DUNEVision target and removed problematic group overrides | shared file를 target에 포함하고 malformed project warning 제거 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | Recorded E1 complete, remaining G1/F3/C5 pending | broad TODO의 실제 진행 범위 보존 |

### Key Code

```swift
WindowGroup(id: VisionDashboardWindowKind.condition.windowID) {
    VisionDashboardWindowScene(
        kind: .condition,
        sharedHealthDataService: sharedHealthDataService
    )
}
```

```swift
@State private var viewModel = VisionDashboardWorkspaceViewModel(
    sharedHealthDataService: sharedHealthDataService
)
```

## Prevention

visionOS에 새 surface를 추가할 때는 scene 파일에서 바로 HealthKit query를 늘리지 말고, 먼저 shared Presentation loader를 만들고 Swift Testing으로 상태 조합을 고정한다. target source wiring이 필요한 shared 파일은 `project.yml`에 추가한 뒤 `scripts/lib/regen-project.sh`와 platform build로 바로 검증한다.

### Checklist Addition

- [ ] 새 visionOS window/scene가 필요한 경우, reusable data loader를 shared Presentation layer에 둘 수 있는지 먼저 확인한다.
- [ ] `project.yml`에 shared path를 추가할 때 `group:` override로 같은 file reference를 중복 생성하지 않는지 확인한다.

### Rule Addition (if applicable)

새 rule 추가는 필요 없었다. `CLAUDE.md` Correction Log의 XcodeGen multi-group 경고 규칙(#203)이 이번 케이스를 이미 커버한다.

## Lessons Learned

visionOS window 확장은 UI보다 데이터 계층을 먼저 공유하는 편이 훨씬 빠르다. `WindowGroup` 자체는 간단하지만, 실제로는 각 window가 같은 health summary를 필요로 하므로 shared loader + tests를 먼저 만들면 다음 phase의 voice/shareplay window도 같은 패턴으로 붙일 수 있다.
