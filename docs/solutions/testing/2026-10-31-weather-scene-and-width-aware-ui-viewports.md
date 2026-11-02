---
tags: [swiftui, canvas, weather, dynamic-type, ipad, ui-testing, viewport]
category: testing
date: 2026-10-31
severity: important
related_files:
  - DUNE/Presentation/Dashboard/WeatherDetailView.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
related_solutions:
  - docs/solutions/architecture/weather-detail-page-outdoor-fitness.md
---

# Solution: Bound weather scenes and use actual tab placement in UI viewports

## Problem

The weather screen needed condition-specific visual depth while retaining its existing data and navigation. A generic bottom-tab assumption in the new UI helper would also reject valid wide layouts: actual iPad accessibility evidence exposes top tab buttons under Other, with no TabBar element. A missing frame or top tab minY cannot define the bottom of the content viewport.

## Solution

The existing weather data now drives a bounded Canvas for day/night, sun/moon, cloud, rain, snow, wind and fog. A single TimelineView is limited to12fps and paused when less than half of the hero is visible, the scene is inactive, Reduce Motion is enabled or a static visual audit is running. Text remains independent accessible content; graphics are decorative. Palette layers use existing semantic color assets.

Only an existing, hittable tab bar below the scroll midpoint trims the bottom of the front scroll viewport. Otherwise use the actual scroll/window intersection. The card must fit fully below navigation before its real tap; the temperature and condition must fit fully in the detail viewport in variant checks. Swipe bounds remain finite.

```swift
let bottom = tabBar.exists && tabBar.isHittable && tabBar.frame.minY > scrollFrame.midY
    ? min(scrollFrame.maxY, tabBar.frame.minY - 8)
    : scrollFrame.maxY
```

The three phone checks passed atae9ef78e. After the test-only viewport correction, the existing normal weather method passed on iPad and both actual Duo postures ata52ddbeb. Production weather code was identical across these capture revisions. Official result bundles, fresh PNGs, Duo sensor/display/AX readbacks and correct original captures are retained in the [native comparison](../../design/full-redesign-map/review/weather-detail-2026-10-31/index.html). The initial DEBUG snapshot compile failure lacked an explicit return after adding statements before an optional switch result; the single corrected build passed, and its original failure remains preserved.

## Prevention

- Inspect actual top/bottom navigation placement before defining visible content bounds; keep frame/hittability assertions meaningful.
- Keep condition-art mock arguments opt-in behind positive UI-test and mock-seed gates. Do not alter default production snapshots or calculations.
- Keep sparse hourly precipitation slots equal in height so neighboring values align.
- Pause decorative timelines offscreen and in inactive/reduced/static states; do not imply an energy benchmark from a code limit.
- Preserve actual source identities per image when only tests change between devices. Refresh only the changed screen records in the shared actual map.

No `.claude` source rule or CI policy changed. Existing scoped verification rules cover this pattern.

## Lessons Learned

A deterministic static visual check can prove readable layout without proving live weather accuracy or sustained animation performance. The snow-at21°C fixture intentionally isolates condition artwork; it is explicitly mock data and is not a meteorological forecast. No full local regression or Cartesian product of every weather/theme state was required or claimed.
