# Life device capture collection

Source revision: `c80b5f1e3e690704421ba6b595c182f12bb4c2f8` (frozen); app source unchanged at `62d3c097` per task contract. Device ownership verified from `.codex-checks/worktree-simulators.json` before operations.

## iPhone

- Device: iPhone 18 Pro-wt-Health-4d0d-62cf3693c151 (`E31D1A6A-8649-4FCF-9DAE-76DD59DE0192`).
- Existing selector `DUNEUITests/LifeRegressionTests/testWeeklyAndFutureRecurringHabitsStayOutsideTodayProgress`: 1 passed, normal exit 0. Receipt `.codex-checks/life-run/ui-phone-final.log.result.json`; log `.codex-checks/life-run/ui-phone-final.log`.
- This is separate from the requested capture selector and does not establish keyboard testing. The phone was shut down to free resources before Duo setup.

## iPad

- Device: iPad Pro 13-inch (M5)-wt-Health-4d0d-62cf3693c151 (`48083538-F9F9-4A38-959E-4125477F6914`).
- Command: `bash scripts/test-ui.sh --no-regen --no-stream-log --test-plan DUNEUITests-DesignCapture --simulator-udid 48083538-F9F9-4A38-959E-4125477F6914 --only-testing DUNEUITests/LifeFlowUITests/testCaptureL01AndPastRecordLightDarkAndMaximumAX --log-file .codex-checks/life-run/ui-ipad-final.log`.
- Result: 1 executed, 1 passed, 0 failed/skipped, normal exit 0. Receipt `.codex-checks/life-run/ui-ipad-final.log.result.json`; log `.codex-checks/life-run/ui-ipad-final.log`; result bundle `.deriveddata/ui-tests/Logs/Test/Test-DUNEUITests-2026.10.29_01-16-48-+0900.xcresult`.
- 61 attachments exported to `.codex-checks/life-run/export-ipad-final/` using `xcrun xcresulttool export attachments`. The bundle contains named L01/L09 light, dark and maxAX capture PNGs with AX hierarchy attachments; see `manifest.json`.
- Simulator viewport native size: 2064×2752 pixels (log capture labels). No gallery import was performed.

## Duo external posture

- Device: iPhone Duo-wt-Health-4d0d-62cf3693c151 (`8B6A9C9D-1364-4EBA-A6F9-832F1BEB201D`). Reviewed hinge source revision verified: `7acb090dd7d28fb0aea8e1907211ceff15aa450e` at `/tmp/life-hinge-20261029`.
- Setup was separately executed under repository and worktree simulator locks: shut down owned iPhone, booted owned Duo, then `XDG_CACHE_HOME=/tmp/life-hinge-cache /tmp/life-hinge-20261029/skills/hinge/scripts/hinge -d 8B6A9C9D-1364-4EBA-A6F9-832F1BEB201D 0`, followed by `xcrun devicectl device info displays --device 8B6A9C9D-1364-4EBA-A6F9-832F1BEB201D`.
- SDK has no hinge motion/get command. Angle is unverified; setter success is not treated as measured posture. Display readback showed LCD (displayId 1) active, bounds/native size 1398×2034, backlight on; LCD-1 (displayId 3) inactive, bounds/native size 2007×2853, backlight off.
- Host collector command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/duo-visual-audit.py .codex-checks/life-run/duo-closed-final 8B6A9C9D-1364-4EBA-A6F9-832F1BEB201D all bash scripts/test-ui.sh --no-regen --stream-log --test-plan DUNEUITests-DuoAudit --simulator-udid 8B6A9C9D-1364-4EBA-A6F9-832F1BEB201D --only-testing DUNEUITests/LifeFlowUITests/testCaptureL01AndPastRecordLightDarkAndMaximumAX --log-file .codex-checks/life-run/ui-duo-closed-final.log`.
- Failed during first `root after setup` collector checkpoint, before L01/L07/L08/L09 checkpoints. Runner receipt `.codex-checks/life-run/duo-closed-final/runner-result.json`: returncode 130, termination `Capture failed or expired at checkpoint 1`, one checkpoint attempted. Checkpoint has `acknowledged=false`, `valid_evidence=false`, elapsed 12.286 sec. `captures.tsv` records screenshot statuses 124 and 0 (non-success); no usable native pair/AX checkpoint evidence. App test selector is not a pass; no UI result receipt was produced.
- Per bounded execution contract, stopped without retry. Duo internal posture was not attempted. Captures/action details and failure logs remain in `.codex-checks/life-run/duo-closed-final/` and `.codex-checks/life-run/ui-duo-closed-final.log`.

## Environment diagnosis

The first sandbox-default `xcrun simctl list devices` probe failed with a CoreSimulatorService connection-refused message. Parent subsequently demonstrated that elevated simulator access succeeds and all registered devices are present (`devices-elevated-probe.json`); therefore the initial failure was sandbox access, not a daemon failure. Collection resumed via approved escalation. No repeated device-list probe was used as an execution retry.

Software keyboard tests are outside this capture run. User-confirmed phone keyboard state remains separate evidence.

## Duo external retry after warmup

- Parent verified a warmup `simctl io <owned-Duo> screenshot` succeeded in 0.972s; this changed capture-readiness evidence and authorized the single retry. First failed run remains preserved.
- Retry command used the same plan/selector/route with fresh paths: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/duo-visual-audit.py .codex-checks/life-run/duo-closed-retry 8B6A9C9D-1364-4EBA-A6F9-832F1BEB201D all bash scripts/test-ui.sh --no-regen --stream-log --test-plan DUNEUITests-DuoAudit --simulator-udid 8B6A9C9D-1364-4EBA-A6F9-832F1BEB201D --only-testing DUNEUITests/LifeFlowUITests/testCaptureL01AndPastRecordLightDarkAndMaximumAX --log-file .codex-checks/life-run/ui-duo-closed-retry.log`.
- Checkpoint 1 through 21 each have both native PNGs and a fresh AX hierarchy; all are acknowledged and `valid_evidence=true`. The selected named checkpoints (14 total across L01 light/dark/maxAX, L07 light, L08 light, L09 light/dark) are mapped in `.codex-checks/life-run/duo-closed-retry/named-capture-map.json`. Active LCD PNG is 1398×2034 px, paired inactive LCD-1 PNG is 2007×2853 px; AX Main Window is {{0,0},{466,678}} pt at scale 3. Active display identity comes from `devicectl` readback (LCD displayId 1); inactivity comes from LCD-1 displayId 3 state, not pixel darkness.
- Despite the successful named checkpoint captures, the overall selector failed: XCTest exceeded its 300-second execution allowance during the subsequent past-record path, xcodebuild exit 65. Receipt `.codex-checks/life-run/duo-closed-retry/runner-result.json`; 21 checkpoints are valid capture evidence but are not a passing selector result.
- No synchronization setup prompt appeared in the observed app hierarchy/log. No sync option was changed. Per stop-on-failure contract, no further retry and no Duo internal posture run were started.

## Duo external split captures (source `791b8bf4983cd5991297655a6f67faa2cf511c2e`)

- App source remains unchanged at `62d3c097`. The same capture loop was split into focused host-only selectors. No new tools, apps, or devices were installed/created.
- External posture was explicitly set to target 0 under repository/worktree simulator locks. Display readback: LCD/displayId 1 active, native 1398×2034; LCD-1/displayId 3 inactive, native 2007×2853. Actual angle remains unverified because current SDK provides no hinge get.
- Three sequential standard host-collector runs all passed 1/1 with normal exit 0:
  - `testHostCaptureLight`: `.codex-checks/life-run/ui-duo-closed-split-light.log`, receipt `.codex-checks/life-run/ui-duo-closed-split-light.log.result.json`.
  - `testHostCaptureDark`: `.codex-checks/life-run/ui-duo-closed-split-dark.log`, receipt `.codex-checks/life-run/ui-duo-closed-split-dark.log.result.json`.
  - `testHostCaptureMaximumAX`: `.codex-checks/life-run/ui-duo-closed-split-maximum-ax.log`, receipt `.codex-checks/life-run/ui-duo-closed-split-maximum-ax.log.result.json`.
- Fifteen named L01/L07/L08/L09 checkpoint maps point to active LCD PNGs, paired inactive LCD-1 PNGs, and fresh AX hierarchy files; each checkpoint was acknowledged and marked valid. Main app window was 466×678 pt at scale 3. Full paths, dimensions, display IDs, action labels, and checkpoint receipts are in `.codex-checks/life-run/duo-closed-split/named-capture-map.json`.
- Internal target 180 was issued under locks, but display readback still showed LCD active and LCD-1 inactive. No angle get is available, so internal posture was not verified. Per parent direction, no internal UI/test operation was run by this collector. Do not treat the external pairs as internal evidence.
- Earlier aggregate retry failure remains recorded: the combined selector exceeded 300 seconds after 21 valid ACK checkpoints. Its checkpoints are valid individual captures, while its selector receipt remains failed.
- No synchronization setup prompt appeared in these observed screens/logs.

## Duo internal split attempt

- Parent-established GUI evidence: `.codex-checks/life-run/duo-open-gui-displays.json` reports LCD-1/displayId 3 active with expected inner viewport; `.codex-checks/life-run/duo-gui-open-and-sync.json` records the existing iCloud sync consent prompt enabled and dismissed. No new app/tool/device was installed or created.
- One combined host collector invocation requested all three selectors (`testHostCaptureLight`, `testHostCaptureDark`, `testHostCaptureMaximumAX`) as instructed, using `DUNEUITests-DuoAudit`, the registered Duo UDID, and output `.codex-checks/life-run/duo-open-split` / `.codex-checks/life-run/ui-duo-open-split.log`.
- Collector stopped at checkpoint 2 (L01 hero-dark). Runner receipt reports returncode 130, `Capture failed or expired at checkpoint 2`; checkpoint 1 root setup was ACKed and valid, checkpoint 2 was not ACKed and marked invalid. Both checkpoint-2 screenshot commands returned 124, so no valid paired capture or named internal evidence was produced. The combined test run has no pass receipt or normal exit.
- Stopped without retry or further device operations. Internal capture remains incomplete; do not label the parent GUI proof as app screenshot evidence.

## Duo internal split retry (source `791b8bf4983cd5991297655a6f67faa2cf511c2e`)

- Parent verified inner-screen posture and existing iCloud consent completion in `.codex-checks/life-run/duo-open-gui-displays.json` and `.codex-checks/life-run/duo-gui-open-and-sync.json`. Readback: LCD-1/displayId 3 active, orientation landscapeRight, panel bounds 2007×2853 px, app Window 951×669 pt; LCD/displayId 1 inactive.
- The first combined attempt stopped at checkpoint 2 when `simctl` exceeded 8 seconds for both display captures. Parent then captured the active inner display successfully in 0.957s at `.codex-checks/life-run/duo-internal-after-timeout.png`, establishing changed readiness and authorizing one retry. Original failed attempt remains preserved.
- The one authorized retry used one standard host-collector invocation with three `--only-testing` selectors: `testHostCaptureLight`, `testHostCaptureDark`, `testHostCaptureMaximumAX`. Log `.codex-checks/life-run/ui-duo-open-retry.log`; result receipt `.codex-checks/life-run/ui-duo-open-retry.log.result.json`.
- Result: 3 executed, 3 passed, 0 failed/skipped, normal exit 0. Host runner receipt `.codex-checks/life-run/duo-open-retry/runner-result.json` reports exit 0 and 27 checkpoints. All 27 ACKs are valid. The 15 named L01/L07/L08/L09 states are mapped in `.codex-checks/life-run/duo-open-retry/named-capture-map.json`, each with active inner LCD-1 PNG, paired inactive outer LCD PNG, and fresh AX hierarchy. Captured inner PNGs are 2853×2007 px; outer PNGs 2034×1398 px. The app window is 951×669 pt at scale 3.
- Parent handled the iCloud consent dialog using the existing configured state, clicked `cloud-sync-consent-enable-button`, dismissed the modal, and selected Life. Details are in the referenced sync evidence; no credentials were entered and no app/tools/devices were installed.
