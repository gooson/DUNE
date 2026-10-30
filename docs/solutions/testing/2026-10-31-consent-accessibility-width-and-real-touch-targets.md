---
tags: [swiftui, dynamic-type, accessibility, consent, touch-target, screenshot-provenance]
category: testing
date: 2026-10-31
severity: important
related_files:
  - DUNE/Presentation/Shared/CloudSyncConsentView.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
related_solutions:
  - docs/solutions/general/2026-03-08-cloud-sync-consent-localization-leak.md
---

# Solution: Validate consent content width and actual touch frames

## Problem

The redesigned consent sheet preserved all choices and SF Symbols, but native verification exposed three distinct issues. The first maximum-text test swiped inside the pinned footer rather than the information scroll region. After that test passed, visual inspection found a large leading badge forcing explanations into narrow one-word lines. A later standard-text Duo accessibility tree showed the secondary plain button at42pt, despite a preliminary source estimate of44pt.

### Root Cause

Existence and hittability alone do not establish readable text geometry or a minimum tap target. A scaled icon in a horizontal row competes with text at accessibility sizes. Padding arithmetic also depends on real font metrics and button style. Tests must derive the scroll gesture from the visible content region above a safe-area inset.

## Solution

| File | Change | Reason |
|---|---|---|
| CloudSyncConsentView.swift | Accessibility-only vertical InfoRow; decorative badge cap64pt | Preserve system text size and full explanation width |
| CloudSyncConsentView.swift | Explicit secondary label minimum44pt after padding | Guarantee actual standard-text tap target |
| TodaySettingsRegressionTests.swift | Bounded gesture above footer; full title visibility and actual button frame assertions | Verify content can be reached and choices can be tapped |
| Native comparison gallery | Four final device images with source revision, original image provenance and hashes | Keep browser proposals, before images and actual current evidence separate |

```swift
Text("Keep on This Device")
    .font(.subheadline.weight(.semibold))
    .frame(maxWidth: .infinity)
    .padding(.vertical, DS.Spacing.md)
    .frame(minHeight: 44)
    .contentShape(Rectangle())
```

The original gesture failure was retained. The corrected maximum-text method passed, then passed again after the separate vertical-layout refinement. At69241c8f the standard method passed independently on iPhone, iPad, Duo folded and unfolded, checking both actual button heights and hittability. Final native images were reviewed by the execution owner and an independent quality agent. Maximum-text and dark images retain their earlier source revisions; they are not relabelled as the final build.

## Prevention

- Derive gestures from the front scroll view and exclude fixed navigation, tab and action regions.
- Inspect a fresh image after accessibility assertions pass; a reachable paragraph can still be awkwardly narrow.
- Read actual frames for plain buttons instead of inferring height from source padding.
- Use a vertical icon/text arrangement at accessibility sizes when the decorative badge would consume substantial line width.
- Preserve failures and source identities across phase changes. A test fix and a later presentation fix are separate findings.

No source-of-truth `.claude` rule was changed. These checks apply through the existing scoped UI gate.

## Lessons Learned

A useful UI gate combines behavior, actual geometry and visual inspection. The forced mock consent tests verify presentation and dismissal, not remote iCloud synchronization or persisted preference semantics; the unchanged production store path was reviewed separately. See the [four-device before/after comparison](../../design/full-redesign-map/review/cloud-sync-consent-2026-10-31/index.html).
