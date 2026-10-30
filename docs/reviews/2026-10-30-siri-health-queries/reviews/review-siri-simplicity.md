# Siri health information — simplicity review

HEAD: `9ae252af61f76afc075c08fc1f995c7b82c4fea1`
Base: `origin/main`
Scope: verification of the two prior P2 findings only. Source review; no build, test, simulator run, or code edit.

## Resolved findings

1. **Unreachable Spotlight indexing subsystem — resolved.** `HealthQuerySearchIndex.swift`, its test, and the unused preference keys were removed. A search across `DUNE` and `DUNETests` found no remaining references.
2. **Routed request loses filters on period change — resolved.** `HealthQueryView.swift` now retains a single editable `HealthQueryRequest` (`request`, line 10). Period changes update only `request.interval` (lines 136–139), and `load()` passes that request without discarding workout, exercise, or comparison fields (lines 146–154). Initial period selection reflects a matching supplied interval or shows “Custom period” (lines 19–26, 44–49). Changing query kind explicitly clears incompatible context (lines 126–134).

No remaining findings within this verification scope.
