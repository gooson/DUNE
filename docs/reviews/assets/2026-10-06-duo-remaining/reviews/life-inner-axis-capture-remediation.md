# Life Book/Open inner-axis capture gate — 2026-10-06

The existing three-state Life numeric test passed behavior and captured the full heading/progress. Native Book 014/017 and Open 022/025 show the actual `Other(identifier: habit-completion-chart)` at roughly `{36,156,795,642.7}`, ending near y=799 while the window ends at y=669. The X-axis date pixels were below the captured viewport, not shown to be internally clipped. Closed 005/006/008/009 already covered those axes.

Added only `DuoLifeNumericLayoutTests.testInnerChartLowerAxesAtMaximumTextSize` in `DUNEUITests/Full/DuoRemainingRouteTests.swift`. The opt-in fold test covers Book (`partiallyOpen`) and Open (`openFlat`), selects both complete Weekly/Monthly controls, then uses the actual Chart `Other` frame to drive bounded 25%-height slow drags. It requires the chart bottom at least 48 points above the scroll/window bottom, at least its final 96 points visible, and both horizontal edges inside the window. Separate native captures are named `Life <state> <period> inner chart lower axis with 48pt clearance`. It makes no whole-chart-in-one-viewport demand and repeats no hero/heading check.

`xcrun swiftc -frontend -parse DUNEUITests/Full/DuoRemainingRouteTests.swift` passed. Native execution remains parent-owned; no simulator, build, git, ACK/PNG copying, or image editing occurred.
