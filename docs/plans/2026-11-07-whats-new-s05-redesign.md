# B08 S05 What's New list — private source proposal

Status: source-only, no repository edit, SDK, simulator, or new capture. Prepared against worktree HEAD `2930ba45dd419634932ef3e4ced117ae13b7556e`; target `DUNE/Presentation/WhatsNew/WhatsNewView.swift` SHA-256 `2c797c4e30038e39c0b98d8f67e7f3b28d79d471f02f7614a8df9eb2ea9de340`. Shared one-file candidate and patch hashes are listed in `README.md`. Recheck target hash before applying because B07 work is active.

## Existing screen and contract

- Actual map row S05 is “새 소식”; regular path `docs/design/phone-design-map/actual/regular/images/S05.png` SHA-256 `c457b8fb557976a40fbb43fcc4627f7a0f9c99e1492f58d786788f32eeaf4f56`. It records `TodaySettingsRegressionTests/testVisualAuditWhatsNew()` via `dashboard-toolbar-whatsnew`.
- Current manual/automatic modes, `visibleReleases` first/all behavior, current release version and intro, feature sequence, area badge, original `feature.symbolName`, NavigationLink to S06, automatic Done/dismiss and `onPresented` are unchanged.
- Native `ScrollView`, row identity, AX IDs and all supplied release data remain. No new copy or catalog key.

## Candidate

- Give the list a 680pt maximum readable width and centered outer frame for iPad/Duo open, while keeping full compact width.
- At accessibility Dynamic Type, stack the `Version` label and actual version number; keep the exact supplied version and existing intro.
- At accessibility sizes, stack each feature's existing icon above its badge/title/summary; allow title and summary to grow vertically. Ordinary sizes retain the current horizontal row and three-line summary limit.
- Use `.scrollBounceBehavior(.basedOnSize)` for dynamic content. No eager card or new animation work.

## Map-before-code and verification

1. Reconcile `S05-layout.html` into a dedicated `docs/design/layout-map/` page and link it from layout index/README. Reconcile `S05-theme.html` into theme-map themes/manifest/README, then run its builder/check before app patch. HTML uses the historical 0.8.0 capture as illustration, not current-version truth or a native screenshot.
2. Apply only the shared WhatsNew source patch after checking its baseline hash and S06 plan; avoid splitting one file into conflicting edits.
3. Focused existing UI candidates: `DUNEUITests/TodaySettingsRegressionTests/testVisualAuditWhatsNew` (opt-in visual scroll), `DUNEUITests/SettingsSmokeTests/testWhatsNewLinkExists`, `testNavigateToWhatsNew`. Add one targeted MAX S05 row/version visibility check only if native audit shows an unverified fit risk. The exact actual-map route from the dashboard must be preserved; settings entry continues through NotificationHub News.
4. Recapture fresh S05 actual regular iPhone, iPad and affected Duo closed/open states after implementation, including MAX and current release data. Historical images are baseline only.

## Risks

- AX `.accessibilityElement(children: .combine)` on a feature row must still expose the complete title/summary and remain tappable after stacking.
- Longer Korean/Japanese titles and release versions can enlarge each row; verify list scrolling and no overlap with bottom tab bar or navigation.
- Different current releases and automatic mode may render fewer features than the old 0.8.0 screenshot; test the actual supplied data, not a fixed row count.

## Current execution contract

B08 S05/S06: same target incremental compilation; exact new WhatsNewVisualAuditTests three phone cases, iPad representative normal and MAX. Original smoke cases/helpers unchanged. New dedicated class uses existing launch fixtures. Per-screen source/review/actual PNG/AX/compound/PR; no separate duplicate build or full regression. Duo capture pending after fresh-device migration failure. Prior P03/P08/S03/H08 counters remain unchanged.

## Scoped completion evidence

[New native PNG/AX and original run counts](../design/full-redesign-map/review/whats-new-s05-2026-11-07/index.html). Phone initial compile0, corrected3/3; iPad exact2normal/MAX, raw receipts authoritative. Existing hero repeated MAX title ellipsis and Duo missing captures are explicit limits.
