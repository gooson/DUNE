---
tags: [swiftui, notification-routing, navigation, task-cancellation, accessibility, native-back]
category: architecture
date: 2026-11-03
severity: important
related_files: [DUNE/Presentation/Activity/ActivityView.swift, DUNE/Presentation/Shared/NotificationTargetNotFoundView.swift, DUNEUITests/Full/ActivityExerciseRegressionTests.swift]
related_solutions: []
---

# Consume a notification event once and verify stable native Back

## Problem

The T14 maximum-text check displayed the full missing-workout payload but failed after native Back: the fallback remained in front. That original result did not trace route-handler execution, so it does not prove replay was the mechanism. Independently, the Activity handler could process an unchanged positive route signal again when its task restarts and an older asynchronous refresh could present after a newer signal.

## Solution

The Activity view captures each positive signal, skips an already consumed signal, and records consumption immediately before presentation in each existing destination path. A separate active signal and cancellation checks reject an obsolete refresh completion. New signals remain eligible even when the workout ID is the same. No new query, model, service or persistence is introduced.

The existing maximum-text method retains its full ID geometry, actual content and real Back checks. It additionally requires the fallback to disappear, Activity's root to be hittable, and three seconds of sampled absence of replay or root loss. On clean90709, one specifically approved standard-runner execution passed1/1 with all old failure histories unchanged. This proves that bounded interaction on the recorded Phone configuration, not the cause of the historical failure or exhaustive concurrent-event behavior.

## Prevention

Keep event identity separate from destination identity, consume at presentation, and check cancellation and current event after suspension. A test waiting only for an underlying root's existence cannot establish that the top destination has closed; require the old destination to disappear and the root to be interactive.

Preserve original native failures and consume each explicitly bounded retry before dispatch. Keep screenshots of a post-Back root as supplemental interaction evidence, never as the detail's canonical image. Source-matched historical iPad/Duo normal captures support normal payload rendering and arrival, not current-source Back behavior. Reuse the fresh generic-route Phone result without implying that every historical device executed its new assertions.

## Lessons Learned

A successful assertion must express the user's visible outcome. One bounded native check can establish actual Back and stability while source review separately evaluates event generations and cancellation. Keep runtime evidence, static reasoning and unproven historical causes distinct.
