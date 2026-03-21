---
tags: [testing, ci, nightly, localization, xcstrings, posture, watch-ui]
category: testing
date: 2026-03-22
severity: important
related_files:
  - DUNE/Data/Services/PostureCaptureService.swift
  - DUNE/Data/Services/TemplateReportFormatter.swift
  - DUNE/Domain/UseCases/GenerateWorkoutReportUseCase.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNE/Presentation/Posture/Components/ZoomablePostureImageView.swift
  - DUNEWatch/Views/ControlsView.swift
  - DUNEWatch/Views/RestTimerView.swift
  - DUNEWatch/Views/SessionPagingView.swift
  - DUNEWatch/Views/SessionSummaryView.swift
  - DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift
  - DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift
  - DUNETests/ActivityViewModelTests.swift
  - DUNETests/PostureAnalysisServiceTests.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/testing/2026-03-12-ci-nightly-test-failures-fix.md
  - docs/solutions/general/xcstrings-format-specifier-mismatch.md
  - docs/solutions/general/2026-03-15-posture-photo-orientation-zoom-nav.md
  - docs/solutions/testing/2026-03-12-watch-ui-smoke-surface-fallback-hardening.md
---

# Solution: Nightly Run #23359618963 Failure Fix

## Problem

GitHub Actions run `23359618963` (`Nightly Full Tests (Unit + UI)`) failed in both the iOS unit lane and the watch UI lane.

### Symptoms

- `nightly-ios-unit-tests` crashed while generating the weekly workout report and still contained several stale expectations from already-shipped behavior.
- posture regression coverage failed for normalized JPEG handling, especially when old-photo fallback and new capture metadata overlapped.
- `nightly-watch-ui-tests` intermittently failed to reach controls, rest timer, or summary surfaces during the seeded strength workout flow.

### Root Cause

1. **Weekly report localization crash**
   - The summary string `"You trained %lld days %@ with %lld sessions totaling %lld kg volume."` had ko/ja translations that reordered placeholders without positional specifiers.
   - `String(localized:)` interpolation is safe only when translated placeholder order stays compatible, so the weekly report path crashed at runtime instead of failing softly.

2. **Posture normalization marker drift**
   - New posture JPEGs only carried the normalization marker in TIFF software metadata.
   - Legacy-orientation fallback treated some new images as if they were old unnormalized captures because the read path did not honor an alternate metadata location.

3. **Watch UI smoke instability**
   - Screen-level identifiers and child accessibility were too loosely coupled, so CI sometimes found the wrapper but not the actionable controls.
   - The controls smoke depended on swipe navigation from metrics, which could still land on a neighboring page instead of the intended controls surface.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/TemplateReportFormatter.swift` | kept localized interpolation, removed explicit `String(format:)` workaround | stay aligned with localization rule while preserving the corrected xcstrings contract |
| `DUNE/Domain/UseCases/GenerateWorkoutReportUseCase.swift` | restored interpolation-based highlight strings | avoid rule drift and keep keys consistent with the catalog |
| `Shared/Resources/Localizable.xcstrings` | changed ko/ja weekly-summary translation to positional placeholders | make reordered arguments runtime-safe |
| `DUNETests/ActivityViewModelTests.swift` | added xcstrings placeholder-order regression test and awaited weekly report generation directly | prevent silent recurrence and remove task-timing flakiness |
| `DUNE/Presentation/Activity/ActivityView.swift` / `ActivityViewModel.swift` | made weekly report generation awaitable with stale-request protection | remove unstructured task races in the Activity screen |
| `DUNE/Data/Services/PostureCaptureService.swift` | write normalization marker to TIFF software and EXIF user comment | make new posture captures self-identifying across decode paths |
| `DUNE/Presentation/Posture/Components/ZoomablePostureImageView.swift` | read posture marker from TIFF or EXIF | avoid applying legacy rotation to newly normalized images |
| `DUNETests/PostureAnalysisServiceTests.swift` | generate JPEG fixtures with both metadata markers | lock the compatibility contract in tests |
| `DUNEWatch/Views/*` | added `.accessibilityElement(children: .contain)` and deterministic controls start hook | keep screen identifiers stable without swallowing child controls |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | added relaunch support, localized label fallbacks, and more resilient control detection | remove watch surface flakiness caused by AX wrapper differences |
| `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift` | launch the controls smoke directly on the controls tab | replace swipe heuristics with deterministic state |

### Key Code

```swift
// Localized interpolation remains the source of truth.
String(
    localized: "You trained \(report.stats.activeDays) days \(periodName) with \(report.stats.totalSessions) sessions totaling \(Int(report.stats.totalVolume)) kg volume."
)
```

```swift
// Reordered translations must use positional placeholders.
"value" : "%2$@에 %1$lld일간 %3$lld세션으로 총 %4$lldkg 볼륨을 훈련했어요."
```

```swift
// New posture captures write the normalization marker in both places.
kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFSoftware: marker],
kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: marker],
```

## Prevention

### Checklist Addition

- [ ] multi-argument xcstrings translations that reorder values must use positional placeholders (`%1$lld`, `%2$@`, ...)
- [ ] localized report generation changes must include a catalog-level regression test, not just a happy-path UI assertion
- [ ] posture JPEG normalization changes must verify both write-path and read-path marker handling
- [ ] watch UI flow fixes should prefer deterministic launch hooks over swipe-only navigation assumptions

### Rule Addition

없음. 기존 `localization.md`에 positional placeholder 규칙이 이미 있었고, 이번 수정은 그 규칙을 테스트로 강제하는 방향으로 닫았다.

## Lessons Learned

- CI incident는 과거 커밋 기준 failure와 현재 HEAD 기준 live defect가 섞일 수 있으므로, 먼저 현재 코드에서 재현 가능한 실패만 분리해야 한다.
- xcstrings 문제는 번역 텍스트 자체가 런타임 crash를 만들 수 있으므로, placeholder order를 정적 검증하는 테스트가 일반 UI assertion보다 더 중요하다.
- watch UI smoke는 접근성 식별자만 추가하는 것보다, 시작 surface를 고정하고 label fallback을 helper에 모아두는 편이 훨씬 안정적이다.
