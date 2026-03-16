---
source: manual
priority: p1
status: done
created: 2026-03-14
updated: 2026-03-14
---

# Notification Tap Main-Thread Crash Fix

## Summary

- Symptom: OS notification tap cold-start path crashed with `Call must be made on main thread`
- Scope: `ContentView` notification navigation fallback path
- Outcome: cold-start notification navigation state mutation is now applied only through an explicit `@MainActor` boundary

## Artifacts

- Plan: `docs/plans/2026-03-14-notification-tap-main-thread-crash-fix.md`
- Solution: `docs/solutions/general/2026-03-14-notification-tap-main-thread-crash-fix.md`
