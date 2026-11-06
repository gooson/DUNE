# B08 S06 What's New feature detail — private source proposal

Status: source-only, no repository edit, SDK, simulator, or new capture. Prepared against worktree HEAD `2930ba45dd419634932ef3e4ced117ae13b7556e`; same target source SHA-256 `2c797c4e30038e39c0b98d8f67e7f3b28d79d471f02f7614a8df9eb2ea9de340` as S05.

## Existing screen and contract

- Actual map row S06 is “새 기능 상세”; regular path `docs/design/phone-design-map/actual/regular/images/S06.png` SHA-256 `cf72afe51ec9f11d57f9400adbb417f8a6fbb54cd99db41b981f99d2bc037b03`. Its source is `SettingsSmokeTests/testWhatsNewMuscleMapDetailExists()` before teardown. The historical capture shows Muscle Map release 0.1.0 in Korean; it is not a current-release fixture.
- Keep selected `feature` and `release` data, original symbol/area badge/title/summary/version, hero screenshot vs SF Symbol fallback branch, supplied intro, navigation title/back, mode-specific background, artwork AX label/identifier and existing detail route.

## Candidate

- At accessibility Dynamic Type, stack icon, feature text and version badge; at ordinary sizes retain their original horizontal order. The Spacer stays only in the horizontal layout.
- Limit detail content to 680pt readable width centered on wide screens. Keep `heroArtwork` and the single `StandardCard` intro; do not alter image dimensions, symbol art or description text.
- Apply size-based scroll bounce so the detail scrolls only when content requires it. No model, unread, version or dismissal change.

## Map-before-code and verification

1. Reconcile `S06-layout.html` into dedicated layout-map page/index/README; reconcile `S06-theme.html` into theme-map themes/manifest/README with builder/check before applying app source. HTML is a static proposal using the old S06 screenshot text, not native evidence; icons in it are simple placeholders and the app keeps `feature.symbolName`.
2. Apply the shared one-file `WhatsNewView.patch` after baseline check. Existing focused UI selectors: `DUNEUITests/SettingsSmokeTests/testWhatsNewMuscleMapDetailExists`, `testWhatsNewNotificationsDetailShowsArtwork`, `testWhatsNewSleepDebtDetailExists`, `testWhatsNewWidgetDetailExists`. One representative route/artwork test plus a new MAX detail fit/scroll assertion is the narrow proposed core; other selectors are alternatives if the asset branch or route differs.
3. Recapture fresh S06 actual regular iPhone, iPad and affected Duo closed/open states after implementation, including MAX, both screenshot and symbol fallback if both are reachable. Keep the old PNG as prior evidence.

## Risks

- At MAX, version badge moves below summary; confirm the label, badge and header remain readable before the artwork while scrolling.
- The screenshot branch can be empty when an asset name is missing (pre-existing behavior); this candidate does not change asset loading. Confirm whichever current feature route supplies a real asset.
- A feature detail is pushed from What's New; avoid introducing a nested NavigationStack or overriding automatic-mode Done semantics.

## Current execution contract

B08 S05/S06: same target incremental compilation; exact new WhatsNewVisualAuditTests three phone cases, iPad representative normal and MAX. Original smoke cases/helpers unchanged. New dedicated class uses existing launch fixtures. Per-screen source/review/actual PNG/AX/compound/PR; no separate duplicate build or full regression. Duo capture pending after fresh-device migration failure. Prior P03/P08/S03/H08 counters remain unchanged.
