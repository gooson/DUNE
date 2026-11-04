---
tags: [swiftui, form, accessibility, keyboard, body-composition, native-evidence]
category: testing
date: 2026-11-05
severity: important
related_files:
  - DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift
  - DUNEUITests/Full/WellnessRegressionTests.swift
related_solutions:
  - docs/solutions/testing/2026-10-29-simulator-keyboard-and-visible-form.md
---

# Native measurement headers and bounded keyboard evidence

## Problem

The shared Add/Edit Body Record Form displayed three measurement headings without the existing metric symbols. The visual change needed to retain native input, localized units, future-date limits, validation and the same create/update ownership.

The first iPad Add test entered 91.2, but XCTest computed Save's hit point as {-1,-1}; the Form remained visible. Fresh PNG and AX showed the focused software keyboard and visible Save. They did not prove the save handler ran, so this was not evidence of a storage bug or a missing keyboard.

## Solution

Keep NavigationStack, Form, inputs, focus, keyboard toolbar, validation and bottom Cancel/Save unchanged. A private measurementHeader takes LocalizedStringKey and the existing category. It renders neutral DS.Color.textSecondary text beside the original category-colored SF Symbol; only the decorative image is hidden from AX. Weight, Body Fat and Muscle Mass retain their original keys and units. No model, query, synchronization or string-catalog change is needed.

Add four capture calls to existing Add/Edit tests. Following the existing MAX Edit interaction, the normal Add test also attempts the existing keyboard Done before Save. Keep the same save/dismiss/history assertions and add no new assertions or test methods for this cosmetic change.

Five effective existing cases passed across iPhone, iPad, Duo closed/open and closed MAX Edit. The original iPad failure remains separate: six historical executions, five passed and one failed. Actual archive provenance is Xcode 27.2 (27B52); the original pipeline context's 27.1 prefix is retained as a label error with an additive correction, not rewritten into the original attempts.

On iPad the added Done tap itself still reported {-1,-1}, and the keyboard remained visible afterward; the later Save succeeded. Do not claim keyboard dismissal or a proved causal repair there. Phone and Duo open post-Done PNG/AX do show dismissal. Keyboard environment proof and a successful saved record are separate facts.

## Prevention

- Check software keyboard from the current owned device's focused PNG and AX, not typeText alone.
- Preserve failed aggregates and retry the same logical check only after a reviewed, cause-related change.
- Verify each control's actual post-action state before describing a tap as successful.
- Keep the original Form and create/update consumers for presentation-only improvements.
- Bind native captures to source, UID, pose, test plan and actual toolchain. Keep historical images labeled as identity references.
- Reuse compilation from the exact targeted UI run rather than repeating an unrelated full build or unit suite.

## Lessons Learned

Small native headers can preserve visual identity without redesigning input ownership. Passing a complete save flow does not establish every intermediate interaction. Rule promotion is unnecessary; no .claude source was changed.
