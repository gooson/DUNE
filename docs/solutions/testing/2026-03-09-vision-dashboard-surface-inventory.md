---
tags: [visionos, e2e, accessibility, dashboard, testing]
category: testing
date: 2026-03-09
severity: minor
related_files:
  - DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift
  - DUNEVision/Presentation/Dashboard/VisionDashboardView.swift
  - DUNETests/VisionSurfaceAccessibilityTests.swift
  - todos/085-done-p3-e2e-dunevision-dashboard-view.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
---

# Solution: VisionDashboard Surface Inventory

## Problem

`todos/085-ready-p3-e2e-dunevision-dashboard-view.md`는 존재했지만, 실제 `VisionDashboardView`에는 root/section/card selector가 고정되지 않아 E2E Phase 0 inventory를 코드 기준으로 닫을 수 없었다.

### Symptoms

- visionOS `Today` lane 안에서 dashboard 자체를 가리키는 stable root AXID가 없었다.
- quick action card, health metric card, mock-data section을 회귀 기준으로 집을 selector가 없었다.
- TODO 문서의 selector inventory가 빈 상태라 후속 automation/harness 작업이 다시 수작업 리서치부터 시작해야 했다.

### Root Cause

이전 batch에서 `VisionContentView` root lane과 placeholder surface까지만 selector를 고정했고, dashboard 내부 section inventory는 별도 helper/test/TODO sync 없이 남겨뒀다.

## Solution

shared `VisionSurfaceAccessibility` helper에 dashboard surface용 identifier를 추가하고, `VisionDashboardView`와 `VisionSurfaceAccessibilityTests`, TODO 문서를 같은 배치에서 함께 갱신했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | Added dashboard root/section/card/toolbar identifiers | selector drift를 한 곳에서 관리하기 위해 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | Wired accessibility identifiers to root, sections, quick actions, metric cards, toolbar buttons | 실제 visionOS surface에서 바로 assert 가능한 anchor를 만들기 위해 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | Added dashboard identifier stability test | helper mapping이 바뀔 때 회귀를 조기에 잡기 위해 |
| `todos/085-done-p3-e2e-dunevision-dashboard-view.md` | Filled entry route, AXID inventory, assertion scope, deferred lanes | backlog 문서와 코드 기준을 맞추기 위해 |
| `todos/021-ready-p2-e2e-phase0-page-backlog-index.md` | Linked TODO to done filename | backlog 탐색에서 현재 상태를 정확히 반영하기 위해 |

### Key Code

```swift
enum VisionSurfaceAccessibility {
    static let dashboardRoot = "vision-dashboard-root"
    static let dashboardConditionSection = "vision-dashboard-condition-section"

    static func dashboardQuickActionID(for kind: VisionDashboardWindowKind) -> String {
        "vision-dashboard-quick-action-\(kind.rawValue)"
    }
}
```

핵심은 selector 문자열을 view 안에 흩뿌리지 않고 helper에 모아, view wiring과 테스트, TODO 문서가 같은 vocabulary를 공유하게 만든 점이다.

## Prevention

visionOS surface TODO를 닫을 때는 코드/테스트/문서를 따로 처리하지 말고 같은 batch에서 같이 닫는다.

### Checklist Addition

- [ ] 새 visionOS surface inventory를 닫을 때 shared accessibility helper에 selector를 먼저 정의할 것
- [ ] view에 root/section/card anchor를 연결한 뒤 helper stability test를 함께 추가할 것
- [ ] TODO 문서에 entry route, assertion scope, deferred lane을 코드 기준으로 즉시 기록할 것

### Rule Addition (if applicable)

새 규칙 파일 추가는 보류. 같은 종류의 deferred visionOS E2E TODO는 이 solution 문서를 먼저 참조한다.

## Lessons Learned

visionOS E2E backlog는 "문서만 채우기"로는 닫히지 않는다. selector helper, 실제 view wiring, 회귀 테스트, TODO 문서가 같은 commit 안에서 같이 움직여야 다음 surface(`086`, `087`, `088`)도 같은 패턴으로 빠르게 처리할 수 있다.
