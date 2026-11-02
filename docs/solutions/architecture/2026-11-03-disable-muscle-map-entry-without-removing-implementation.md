---
tags: [swiftui, muscle-map, feature-availability, disabled-button, duo, native-evidence]
category: architecture
date: 2026-11-03
severity: minor
related_files: [DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift, DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift]
related_solutions: [docs/solutions/architecture/2026-02-27-muscle-map-detail-view-integration.md]
---

# Disable a 3D entry while preserving its implementation

## Problem

The requested temporary unavailable menu state had two entry paths: the explicit cube button and automatic compact-width navigation on a 2D muscle tap. Disabling only the button would leave the automatic path active; removing the implementation would discard the retained 3D work.

## Solution

`MuscleMapDetailView` uses a local false `is3DMuscleMapEntryAvailable` constant for the existing button's native disabled state and for the compact automatic push. The original 2D selection update remains outside the gate. The 3D view, state, assets, destination and original cube label remain unchanged. Selected detail exposes an accessibility container while keeping its calculation child available. No new user copy, global preference, model or engine is introduced.

The existing focused regression checks the disabled button, 2D selection, selected content and absence of the 3D screen. Historical Phone1f7 source-matched evidence is explicitly bounded; new validation8274 iPad and Duo closed/open each passed one exact case. This establishes normal-text entry availability and selection, not 3D rendering, Back, VoiceOver or maximum text. Five source perspectives and the scoped native quality review found no new findings.

## Prevention

When withholding an entry, inspect both its visible control and gesture-driven navigation. Keep essential selection state outside the availability gate. Preserve original 3D assertions in source with an explicit unavailable-entry skip; a skip is never a 3D runtime pass.

Compare each affected adaptive layout with its own native pixels. The active Duo internal screen is LCD-1 at180°: XCTest screen0 can be black while strict host checkpoint002/003 captures provide the actual internal pixels and matching AX. Preserve both originals, label the host provenance and do not rerun a passing case merely to replace an inactive-display screenshot. The published review preserves source, device, action and pose limits.

## Lessons Learned

A local reversible gate can preserve implementation and native disabled affordances without introducing product settings. Targeted behavior assertions and actual selected-state images complement one another: a compact default viewport does not itself show the offscreen cube. Source-matched reuse and fresh execution must remain distinguishable.
