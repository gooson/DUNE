---
tags: [visionos, window-placement, no-anchor, smoke-test, backlog]
category: testing
date: 2026-03-22
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNEVision/Presentation/Settings/VisionSettingsView.swift
  - DUNETests/VisionWindowPlacementPlannerTests.swift
  - scripts/vision-window-placement-smoke.sh
  - todos/done/020-done-p3-vision-pro-phase4-social-advanced.md
  - todos/done/023-done-p2-vision-phase4-remaining.md
  - todos/done/144-done-p3-vision-window-placement-no-anchor-fallback.md
related_solutions:
  - docs/solutions/general/2026-03-08-vision-pro-todo-state-reconciliation.md
  - docs/solutions/testing/2026-03-16-vision-window-placement-smoke.md
---

# Solution: visionOS No-Anchor Placement Closeout

## Problem

Vision Pro active backlog에는 no-anchor fallback verification과 stale umbrella TODO가 함께 남아 있었다. primary window placement smoke는 이미 자동화됐지만, main window가 사라진 상태에서 `.utilityPanel` fallback이 실제로 접근 가능한지 재현 가능한 근거가 없었다. 동시에 `020`, `023`은 foundation 구현이 끝난 뒤에도 future capability note 때문에 active queue에 남아 있어, backlog만 보고는 "지금 닫아야 할 일"과 "장기 research"를 구분하기 어려웠다.

### Symptoms

- no-anchor fallback은 simulator/device에서 수동 관찰로만 남아 있었다.
- smoke를 다시 돌리면 이전 secondary window restoration이 섞여 artifact가 비결정적으로 보일 수 있었다.
- shipped foundation이 끝난 vision TODO가 active queue를 계속 점유했다.

### Root Cause

문제는 둘 다 "closeout contract"가 없었던 데서 왔다. no-anchor fallback은 primary smoke 이후 별도 manual TODO로만 분리돼 있었고, active umbrella TODO는 shipped foundation과 research-only scope를 같은 문서에 계속 섞어 두고 있었다. 즉, verification path와 backlog semantics가 모두 불완전했다.

## Solution

`VisionWindowPlacementSmokeConfiguration`를 primary/no-anchor mode로 확장하고, no-anchor mode에서는 기존 secondary windows를 먼저 닫은 뒤 settings utility panel을 열고 main window를 dismiss하도록 만들었다. 이후 settings window가 fallback 대상 window를 이어서 열게 해 anchor-less 상태를 반복 가능하게 만들었다. 동시에 smoke script에 no-anchor option과 artifact note를 추가하고, 해당 결과를 근거로 stale umbrella TODO를 `done`으로 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift` | Added smoke mode/config fields and no-anchor window order | primary smoke와 no-anchor smoke를 같은 shared config로 관리하기 위해 |
| `DUNEVision/App/VisionContentView.swift` | Reset pre-existing windows, dismiss main window in no-anchor mode | restoration noise를 제거하고 anchor-less 상태를 보장하기 위해 |
| `DUNEVision/Presentation/Settings/VisionSettingsView.swift` | Continued no-anchor smoke from settings utility panel | TODO 요구사항인 "secondary utility surface에서 reopen" 경로를 코드로 재현하기 위해 |
| `DUNETests/VisionWindowPlacementPlannerTests.swift` | Added no-anchor config coverage | smoke mode regression을 unit test로 고정하기 위해 |
| `scripts/vision-window-placement-smoke.sh` | Added `--no-anchor` option and richer note output | artifact만 봐도 smoke mode와 wait 조건을 알 수 있게 하기 위해 |
| `todos/done/020-done-p3-vision-pro-phase4-social-advanced.md` | Closed stale umbrella TODO with shipped-scope rationale | foundation 완료 후 남은 roadmap note를 active queue에서 제거하기 위해 |
| `todos/done/023-done-p2-vision-phase4-remaining.md` | Archived advanced roadmap umbrella as done note | executable backlog와 research scope를 분리하기 위해 |
| `todos/done/144-done-p3-vision-window-placement-no-anchor-fallback.md` | Recorded no-anchor artifacts and verification result | fallback closeout 근거를 TODO 자체에 남기기 위해 |

### Key Code

```swift
@MainActor
private func runWindowPlacementSmokeIfNeeded() async {
    guard windowPlacementSmokeConfiguration.isEnabled else { return }

    if windowPlacementSmokeConfiguration.shouldSeedMockData {
        applyAdvancedMockDataSeed()
    }

    try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeInitialDelayNanos)
    dismissExistingSmokeWindows()
    try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeStepDelayNanos)

    for windowID in windowPlacementSmokeConfiguration.mainWindowAutoOpenIDs {
        openWindow(id: windowID)
        try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeStepDelayNanos)
    }

    guard windowPlacementSmokeConfiguration.shouldDismissMainWindow else { return }
    try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeDismissDelayNanos)
    dismissWindow()
}
```

## Prevention

- visionOS closeout TODO는 manual note만 남기지 말고 `launch arg + script + screenshot/note artifact`까지 같이 남긴다.
- no-anchor 같은 fallback smoke는 시작 전에 기존 secondary windows를 정리해 restoration noise를 제거한다.
- umbrella TODO에 shipped foundation과 research-only scope가 동시에 들어가면, 후속 배치에서 active queue를 계속 오염시키므로 closeout 시점에 명시적으로 분리한다.

### Checklist Addition

- [ ] no-anchor 또는 fallback smoke는 "기존 window reset -> anchor 제거 -> reopen" 순서를 실제 코드로 보장하는지 확인한다.
- [ ] TODO를 `done`으로 옮길 때 remaining scope가 executable backlog인지 roadmap note인지 구분해 적는다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다. 다만 visionOS backlog closeout에서는 verification artifact와 active-roadmap 구분을 한 배치에서 처리하는 편이 안전하다.

## Lessons Learned

visionOS window placement는 단순히 planner unit test만 통과해서는 닫을 수 없고, fallback branch도 별도 smoke로 재현돼야 한다. 반대로 backlog 측면에서는 "future capability를 적어 둔 문서"가 active TODO로 남아 있으면 구현이 끝난 뒤에도 큐가 비워지지 않는다. smoke automation과 backlog hygiene를 같이 처리해야 Vision Pro 트랙의 상태가 다시 신뢰 가능해진다.
