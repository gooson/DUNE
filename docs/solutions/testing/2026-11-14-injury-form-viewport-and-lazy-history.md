---
tags: [swiftui, xctest, dynamic-type, injury-form, lazy-list, duo]
category: testing
date: 2026-11-14
severity: important
related_files:
  - DUNE/Presentation/Injury/InjuryFormSheet.swift
  - DUNEUITests/Full/WellnessRegressionTests.swift
related_solutions: []
---

# Injury form viewport and saved-row evidence

## Problem

Compact native Form scrolling hid Save/Cancel; fast reveal gestures overshot a tall severity row. Later attempts passed severity but stalled before Memo or failed counting lazy History rows. These are preserved as separate observed failure points, not inferred framework causes.

## Solution

The app keeps original save, validation, field bindings and selected state while improving contrast and section symbols. A bounded return to the Form top restored complete Save/Cancel controls and the normal Closed Add flow passed. Full-field assertions remain.

Closed MAX now passed203.609s with native PNG/AX evidence; Open MAX passed149.472s. The remedies are: compact Memo uses the Form gutter and a short press to avoid starting over the observed native End Date picker; short Duo History verifies the original Active row and the new recovered row sequentially. Recovered is a section header, not a token in the ended row label. Closed MAX verifies actual Memo focus/keyboard dismissal, whole Save/Cancel, Save and new recovered row. It does not type Memo text. Original Active and new recovered rows are observed sequentially. The initial renewed Closed run failed because reading identifier on an absent lazy Start Date element requested a missing snapshot; passing a Boolean from the known selector fixes classification without touching the absent element. That failure remains recorded.

## Prevention

- Use native PNG and AX geometry together. Existence and hittability alone do not establish whole-row visibility.
- Count distinct saved identities across sequential lazy-list views, without requiring simultaneous AX materialization.
- Preserve real keyboard appearance, dismissal, whole Save/Cancel, actual Save and resulting history checks.
- Do not claim changed-field Edit persistence from a test that saves unchanged fields.
- Keep every original failure and authorization record; the missing original H08 counter stays unknown.

## Lessons Learned

A bounded test can fail because its gesture starts on an embedded control. That geometry supports a candidate fix, but does not prove private framework behavior. Closed and Open MAX validation now establishes the selected contract. The Phone/iPad and normal Duo results remain useful within their exact source and action scope.
