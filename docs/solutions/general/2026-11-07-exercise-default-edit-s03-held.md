---
tags: [swiftui, settings, s03, accessibility, ui-testing]
category: general
date: 2026-11-07
severity: minor
status: unresolved
related_files: [DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift, DUNEUITests/Full/TodaySettingsRegressionTests.swift]
related_solutions: []
---

# S03 input layout: implementation and held verification

Native Form keeps its labels, original symbols, bindings, keyboards, parsing, limits, Save/Clear and Watch sync. Normal input rows retain their trailing fields; accessibility rows stack labels above fields. Source review found no new app logic issue.

Phone MAX full field frames, input, Save and values on reopen passed on source47feceb7b. Normal phone Save/reopen values were observed before a new test incorrectly required Cancel inside a native popover. On iPad, the floating number pad covers the reps tap with its 3 key, producing72.53 in weight; no Save happened. After targeting keyboard dismissal the retry still failed its dismissal wait. This is not an iPad Save/reopen pass, and the screen remains a draft.

The four shared results retain8=4pass4fail,4=1pass3fail,5=2pass3fail,4=3pass1fail. Both phone and iPad checks have two failed records. No further SDK is run under a new ID. P03/P08/H08 limits are unchanged. Before, native PNG/AX, sources and raw counts are preserved in the [held gallery](../../design/full-redesign-map/review/exercise-default-edit-s03-2026-11-07/index.html). Official S03 actual-map main rows remain unchanged until the gate is resolved. No Duo current capture exists; a fresh owned device failed Data Migration before SDK and was cleaned after diagnostics were archived. No original l03/batch04 recovery is claimed.

Next work is to resolve the native floating-keyboard/AX visibility contract with concrete evidence and an available execution budget. Do not erase old failures, lower input/readback assertions, or mark this draft complete based only on the phone MAX result.
