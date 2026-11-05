# Batch02 phone native review — T17 and T18

## Findings

### P2 — T17 unavailable hero has an empty icon badge

The fresh unavailable-state PNG (`FD4A0485-27CC-4257-B298-B18488C2C6CC.png`, paired AX `21992BB8-C8D8-49FB-B4C0-A300AD79D7DF.txt`) shows a prominent pale 64 pt circle with no visible glyph above the supported-device explanation. Source uses `Image(systemName: "sparkles.slash")`, preserved from the earlier view; the redesigned hero makes the failed symbol rendering conspicuous. The available `sparkles` and inline Browse icon render normally. Use a valid native SF-symbol composition/fallback with the same unavailable meaning, then capture the affected state again.

### P2 — T17 fallback caption lacks Light readability

The reply PNG (`60838F0D-B07F-4AB3-AF87-5D7DA7DB8121.png`, paired AX `972FB8AC-B2F1-4488-8613-1E9C92BC0005.txt`) shows “Fallback answer” in very pale grey against a white reply card. The original `.foregroundStyle(.tertiary)` remains, but in the new white card it is difficult to read at normal size. Give this status label a stronger semantic text color and recapture the affected reply state. The answer itself is readable.

P1: 0. P3: 0 new native findings. Earlier T17 second-typed-reply test weakness remains P3 in the preintegration report; the first prompt/fixture reply is verified here.

## Verified native scope

The archived phone result reports 3 executed, 3 passed, 0 failed/skipped on source `08ad7dba980d51f2da528a1bad675fb8850c1809`. This review covers only T17/T18 normal English/Light on the iPhone 18 Pro Max. All 30 selected T17/T18 PNG/AX pairs exist and match their recorded SHA-256 values in [`phone-t17-t18-native-review.json`](phone-t17-t18-native-review.json); the failed initial `e2c4b3a0` archive is retained separately.

T17 available overview and all three suggested prompt rows are legible, with leading sparkles, no overlap or clipping. The first prompt creates the expected user bubble and `UI test response.` fallback reply; the composer stays visible. Focused input shows the native software keyboard and remains above it; AX exposes separate leaf IDs for overview, prompt, answer, input and Send. The unavailable paragraphs and inline Browse link are legible, Browse reaches the query screen, and Done returns to Today. The second typed reply completion is not independently established by the current test.

T18's native pin and category SF Symbols render; all labels, checks and footer fit at normal size. The initial HRV/RHR selection, six selected icons/rows, disabled seventh BMI, selected HRV still enabled, Cancel discard and Done persistence after reopening are supported by the paired AX checkpoints and PNGs. No normal-size clipping or overlap is visible.

## MAX-only test delta

After this phone run, `TodaySettingsRegressionTests.swift` gained six lines inside the not-yet-run T18 MAX method: exact title reach, one bounded down swipe, exact title recheck, then a named six-icon preview capture. No App source, shared helper, normal T18 method, assertion strength or timeout changes. Current test file SHA-256 is `62375241b04103fa605f2bcbd6c2a1e23c123a057450c32cd2a2a3a13312d05d`; the phone normal result remains tied to source `08ad7dba` and does not prove the later MAX capture.

No simulator, SDK rerun, Git mutation or Root tracked edit was performed by this reviewer.
