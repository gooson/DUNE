# Code Review Report — Activity·Life hero rhythm

> Date: 2026-10-25
> Scope: main → 59ab9455 plus recorded user UI-gate exception.
> Diff: 9,123 nonbinary lines at review entry; 84 tracked changed files + one exception record.

## Summary

| Priority | Count | Status |
|---|---:|---|
| P1 | 0 | No blocking finding |
| P2 | 0 | No blocking finding |
| P3 | 2 | One metadata cleanup resolved; one intentional compatibility tradeoff retained |

The review skill's ≥2,000-line exception was applied: the parent reviewed five perspectives directly in folder-sized diffs. No claim is made that five reviewer subagents ran. Agent-Native is skipped because no product agent/prompt/adapter source changed. The independent app-quality-gate runs in Phase 3.5.

## Five perspectives

- Security: the new seed branches are inside DEBUG and opt-in UI fixtures. Production UI only reads existing data. No auth, network, input interpreter, persistence schema, credentials or sensitive telemetry added. Documentation PNGs contain synthetic fixture data. Standalone mockup HTML has fixed content and a generated sandbox wrapper; it is not embedded in the app.
- Performance: the existing bounded snapshot API fetches at most 384 rows for 192h. Grouping and sorting occur during load; seven display points are cached. Life aggregation is attached to existing analytics invalidation, including new createdAt/isAutoCompleted inputs, rather than performed in the view body. No added per-day database/HealthKit query or long-lived task.
- Architecture: existing readiness calculation, ScoreRefreshService and HabitAnalyticsService are reused. New Foundation-based daily points have no SwiftData ownership. Existing view-owned analytics projection follows local patterns. Added Xcode references are target-specific app/test sources; no new dependency or Watch consumer.
- Data integrity: readiness excludes nonfinite/out-of-range/future samples, keeps latest valid date values, and ties today to the visible ring. Life counts current active manual habit completion days and excludes cycle actions, auto completion, future logs and days before creation. It does not fabricate historical habit denominators. Existing service upsert/validation makes old memory warnings about snapshot first-caller loss inapplicable to current source. No schema or destructive write change.
- Simplicity: two callers share a small noninteractive display, without chart gesture machinery or new service layers. Missing data, zero and observed values are explicit. No new dead production paths found.

## Localization verification

The five leak patterns and checklist were checked against the changed source. New helper titles use LocalizedStringKey, programmatic missing labels use static String(localized:), numeric/date formatting uses locale APIs, and all seven newly introduced English keys have en/ko/ja translations. Reused keys retain existing ko/ja and English base behavior. No raw enum storage values are newly rendered. Formatter check passed. A reused key's stale extraction state is a P3 metadata cleanup, not a missing translation.

## P3 Findings

### [L10N] L10N-001 — Used Completed key remains marked stale

- File: Shared/Resources/Localizable.xcstrings:9128
- Issue: Completed was reused by the new summary and has all translations, but inherited extractionState=stale.
- Suggestion: Set extractionState to manual and format the catalog. No translated value or rendered string needs to change.
- Status: Resolved. extractionState=manual, complete catalog value equality confirmed, formatter check and post-fix app build passed.

### [Apple UX compatibility] UX-001 — Header and footer both open readiness details

- File: DUNE/Presentation/Activity/ActivityView.swift:505
- Issue: The existing header action and the explicit footer have the same destination.
- Decision: Retain the header accessibility identifier and tappable area to preserve existing interaction/tests; keep the footer discoverable after the new evidence/history. Record as a nonblocking compatibility tradeoff.
- Status: Open, accepted tradeoff. No P1/P2 risk.

## Evidence and limits

App/resource hashes still match the previously built/tested source. Unit 41/41; ten unique new phone hero scenarios, existing Life layout (three states), iPad 4/4 and Duo external 4/4 passed. Native light/dark and MaxAX evidence is preserved. The two notification smoke failures and Duo internal landscape gap remain unchanged under the user's explicit `통과 하고 계속` exception. Targeted success is not full regression or VoiceOver/contrast measurement evidence. Binary PNGs are documentation captures, not new asset-catalog product images.

## Next steps

Resolve L10N-001, reuse unchanged successful source verification with the metadata-only delta explicitly checked, complete independent app quality and final PR review, document the solution and ship.

## Resolve verification

The only post-review product delta is Completed extraction metadata. The parent rechecked all P1/P2 concerns (none) and both P3 items against the current content: L10N-001 resolved, UX-001 intentionally retained. All translation values are identical. The post-fix unsigned iOS build passed, and view/model/test source is unchanged; no duplicate unit/UI run or pixel recapture was added for metadata. User-approved UI limitations remain.
