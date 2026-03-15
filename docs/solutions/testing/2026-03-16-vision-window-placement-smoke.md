---
tags: [visionos, smoke-test, simulator, window-placement, multi-window, launch-arguments]
category: testing
date: 2026-03-16
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift
  - DUNE/Data/HealthKit/HeartRateQueryService.swift
  - DUNE/Data/Services/PostureReminderScheduler.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNETests/VisionWindowPlacementPlannerTests.swift
  - scripts/vision-window-placement-smoke.sh
  - todos/107-done-p2-vision-window-placement-runtime-validation.md
  - todos/141-ready-p3-vision-window-placement-no-anchor-fallback.md
related_solutions:
  - docs/solutions/architecture/2026-03-08-visionos-window-placement-planner.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
---

# Solution: visionOS Window Placement Smoke

## Problem

`VisionWindowPlacementPlanner` 자체는 unit test로 고정돼 있었지만, 실제 DUNEVision multi-window spatial arrangement를 반복 가능하게 확인할 경로가 없었다. `todos/107-*`는 "simulator/device에서 눈으로 확인" 수준의 수동 작업으로 남아 있었고, 검증 결과도 repo 안에서 재현하기 어려웠다.

추가로 이 smoke를 돌리려 하자 visionOS target에는 runtime verification과 무관한 compile break가 숨어 있었다. `PostureReminderScheduler`가 visionOS에 없는 notification helper를 직접 참조했고, `HeartRateQueryService.aggregateHistory`는 vision target에서 제외된 chart aggregation 타입에 의존하고 있었다.

## Solution

launch argument 기반 smoke configuration을 `VisionWindowPlacementPlanner` 옆에 두고, `VisionContentView`는 해당 설정이 켜질 때만 mock data seed와 multi-window open sequence를 자동 실행하도록 만들었다. 그리고 `scripts/vision-window-placement-smoke.sh`를 추가해 build/install/launch/screenshot을 한 번에 수행하게 했다.

visionOS build를 막던 두 compile break는 함께 정리했다:
- `PostureReminderScheduler`는 visionOS에서 사용하지 않으므로 `#if !os(visionOS)`로 제외
- `HeartRateQueryService.aggregateHistory`는 local bucket average 구현으로 바꿔 excluded chart helper 의존을 제거

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift` | Added `VisionWindowPlacementSmokeConfiguration` | smoke launch argument와 auto-open window order를 pure helper로 고정하기 위해 |
| `DUNETests/VisionWindowPlacementPlannerTests.swift` | Added smoke configuration tests | enabled/disabled/order parsing regression을 unit test로 막기 위해 |
| `DUNEVision/App/VisionContentView.swift` | Added 1-shot smoke task + mock seed helpers | simulator launch만으로 dashboard/chart3d window를 자동 오픈하기 위해 |
| `scripts/vision-window-placement-smoke.sh` | Added build/install/launch/screenshot workflow | manual note 대신 repeatable artifact를 남기기 위해 |
| `DUNE/Data/Services/PostureReminderScheduler.swift` | Excluded from visionOS build | visionOS에서 쓰지 않는 notification scheduler가 compile break를 만들지 않게 하기 위해 |
| `DUNE/Data/HealthKit/HeartRateQueryService.swift` | Replaced shared chart helper dependency with local aggregation | visionOS target exclude 설정과 충돌하는 타입 의존을 제거하기 위해 |

## Verification

- Focused unit tests:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' -only-testing DUNETests/VisionWindowPlacementPlannerTests -only-testing DUNETests/HeartRateQueryServiceTests -quiet`
- visionOS build:
  - `scripts/build-target.sh --scheme DUNEVision --platform visionos --build`
- smoke artifact:
  - `scripts/vision-window-placement-smoke.sh`
  - screenshot example: `.tmp/vision-window-placement-smoke/window-placement-20260316-015645.png`

## Prevention

- visionOS manual QA TODO를 닫을 때는 "launch arg + script + artifact path"까지 같이 남긴다.
- shared source가 visionOS target에서 제외된 타입에 의존하면, project.yml을 넓게 흔들기 전에 해당 사용처를 더 좁은 pure helper로 줄일 수 있는지 먼저 본다.
- visual smoke로 primary path를 닫았더라도 device-only/no-anchor fallback은 별도 TODO로 남겨 scope를 정직하게 유지한다.

## Lessons Learned

visionOS window placement는 planner unit test만으로는 끝나지 않는다. 실제로는 "어떤 창을 어떤 순서로 열어야 의도한 spatial layout이 보이는가"까지 재현돼야 backlog를 닫을 수 있다. 반대로 이 smoke를 돌려보면, 평소 안 드러나던 target membership/compile break가 같이 드러나므로 visionOS build를 별도 gate로 자주 돌리는 편이 안전하다.
