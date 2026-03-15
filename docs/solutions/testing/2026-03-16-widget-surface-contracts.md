---
tags: [widget, e2e, testing, accessibility, widgetkit, regression]
category: testing
date: 2026-03-16
severity: important
related_files:
  - Shared/WidgetSurfaceAccessibility.swift
  - DUNE/project.yml
  - DUNEWidget/Views/SmallWidgetView.swift
  - DUNEWidget/Views/MediumWidgetView.swift
  - DUNEWidget/Views/LargeWidgetView.swift
  - DUNEWidget/Views/WidgetPlaceholderView.swift
  - DUNEWidget/Views/WidgetScoreComponents.swift
  - DUNEWidget/WellnessDashboardWidget.swift
  - DUNETests/WidgetSurfaceAccessibilityTests.swift
  - todos/092-done-p3-e2e-dunewidget-small-widget-view.md
  - todos/093-done-p3-e2e-dunewidget-medium-widget-view.md
  - todos/094-done-p3-e2e-dunewidget-large-widget-view.md
  - todos/095-done-p3-e2e-dunewidget-placeholder-states.md
  - todos/101-ready-p2-e2e-phase0-page-backlog-index.md
  - todos/107-done-p2-e2e-phase0-completed-surface-index.md
related_solutions:
  - docs/solutions/general/2026-03-07-widget-visual-refresh.md
  - docs/solutions/architecture/widget-extension-data-sharing.md
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
---

# Solution: Widget Surface Contracts for Deferred E2E Backlog

## Problem

`DUNEWidget`의 phase 0 E2E surface 4건은 backlog에는 있었지만, 실제 widget 코드와 연결된 stable selector contract가 없었다. 이 상태에서는 TODO 문서를 `done`으로 바꿔도 후속 snapshot/preview lane에서 재사용할 source of truth가 남지 않고, layout이나 placeholder 구조가 바뀌어도 자동 신호를 받기 어렵다.

### Symptoms

- small/medium/large widget family별 root/state anchor가 코드에 없었다.
- placeholder state는 문서상 backlog에만 있고, family별 no-data contract가 코드와 테스트로 고정되지 않았다.
- `DUNETests`에서 widget surface selector drift를 감지할 수 없었다.

### Root Cause

Widget regression 전략이 specialized/deferred lane으로 분리되면서, phase 0 surface 정의가 문서 TODO에만 남아 있었다. 즉, widget target에는 visual implementation만 있고, E2E surface contract를 소스 수준에서 고정하는 계층이 빠져 있었다.

## Solution

`Shared/WidgetSurfaceAccessibility.swift`에 family/state/metric selector contract를 정의하고, widget views가 해당 contract를 실제로 사용하게 만들었다. 동시에 `DUNETests`에 contract stability test를 추가하고, 관련 TODO/index 문서를 `done` 상태 기준으로 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Shared/WidgetSurfaceAccessibility.swift` | CREATE | family route, root/state/metric/placeholder identifier를 한 곳에 고정 |
| `DUNE/project.yml` | MODIFY | shared contract 파일을 app/widget target 양쪽에 포함 |
| `DUNEWidget/Views/SmallWidgetView.swift` | MODIFY | small family root/scored/footer placeholder anchor 연결 |
| `DUNEWidget/Views/MediumWidgetView.swift` | MODIFY | medium family root/scored/placeholder anchor 연결 |
| `DUNEWidget/Views/LargeWidgetView.swift` | MODIFY | large family root/scored/footer placeholder anchor 연결 |
| `DUNEWidget/Views/WidgetPlaceholderView.swift` | MODIFY | family별 placeholder anchor 연결 |
| `DUNEWidget/Views/WidgetScoreComponents.swift` | MODIFY | metric container에 family-aware identifier 부여 |
| `DUNEWidget/WellnessDashboardWidget.swift` | MODIFY | widget kind와 supported families를 contract 기반으로 고정 |
| `DUNETests/WidgetSurfaceAccessibilityTests.swift` | CREATE | contract 값의 안정성/유일성/unit coverage 추가 |
| `todos/092-095*.md`, `todos/101*.md`, `todos/107*.md` | MODIFY | widget surface 완료 기록과 backlog index 동기화 |

### Key Code

```swift
enum WidgetSurfaceAccessibility {
    static let widgetKind = "WellnessDashboardWidget"

    static func rootID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-root"
    }

    static func scoredLaneID(for family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-scored-lane"
    }

    static func metricID(_ metric: WidgetSurfaceMetric, family: WidgetSurfaceFamily) -> String {
        "widget-\(family.rawValue)-metric-\(metric.rawValue)"
    }
}
```

## Prevention

### Checklist Addition

- [ ] deferred target surface라도 TODO만 닫지 말고 코드에 stable contract를 먼저 남길 것
- [ ] shared selector contract가 두 target 이상에서 필요하면 `Shared/`에 두고 source membership을 명시할 것
- [ ] completed index로 옮길 때 active backlog와 done backlog를 같은 변경에서 함께 갱신할 것

### Rule Addition (if applicable)

새 rule 파일 추가는 보류한다. 같은 유형의 deferred E2E surface가 생기면 이 solution 문서를 먼저 참조한다.

## Lessons Learned

- widget은 바로 XCUITest로 가지 못하더라도 family/state/metric contract를 먼저 고정하면 backlog를 실제 실행 단위로 전환할 수 있다.
- `Shared/` contract + app unit test 조합은 widget host 하네스가 없을 때도 drift를 조기에 막는 데 유용하다.
- placeholder/stale/scored처럼 host 의존성이 큰 상태는 phase 0 contract와 phase 1 snapshot lane을 분리하는 편이 작업 단위를 더 명확하게 만든다.
