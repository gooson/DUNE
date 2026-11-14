# W34 embedded AI builder — scoped UI verified

W34 is the AI section inside the W13 create Form, reached from Activity’s existing AI Workout Builder action. It adds no screen or route. The original prompt, wand.and.stars icon, Generate callback and availability messages remain. The Generate label and availability message wrap at accessibility sizes.

The fresh 2026-11-14 iPhone normal/MAX selectors passed 2/2, and iPad normal passed 1/1. The original iPad MAX run and its same-ID retry both failed before prompt typing; their native diagnostic PNG/AX pairs and receipts remain in `diagnostics/` and `proofs/`. After the 80px/s, 0.35s-hold test gesture was applied, the user-approved extra iPad MAX selector passed 1/1 at integration source `15450f83d`; its four new positive PNG/AX pairs are in `assets/ipad/MAX-*`. The seven-selector batch was 6 passed, 1 failed (unrelated W04 MAX Cardio input-type assertion), 0 skipped. This is a scoped W34 UI gate, not a global test pass.

The W34 normal and MAX test methods are byte-equal between draft branch `d80273a` and the tested integration source. The AI app section matches compiled source `f7bc00cb2`; the integration source has separate W13 row/summary changes. The original Phone raw xcresult was absent before archive for unconfirmed reasons; its exported PNG/AX, complete log and result receipt remain. Two earlier iPad SDK bundles survived, and the extra batch raw SDK was archived before subsequent tests. None of the old failures or captures was relabeled.

The 16 positive PNG/AX pairs and two earlier failed diagnostic pairs retain original bytes and timestamps; see `manifest.json`, `ipad-MAX-captures.json` and `proofs/`. In MAX, the sample placeholder ellipsizes at the field edge as it did before this change. The filled 30 minute shoulder workout prompt is visually complete above the keyboard; Generate enables and keyboard Done is visible.

Scope: English/light current available state. No Generate or Save action was requested; no model response, Duo, dark mode, ko/ja, or unavailable state is validated. “Available” is the simulator state reported by the app.

Earlier diagnostic measurement: the navigation bar ends at y313; the prior retry button started at y301.5, overlapping the bar by 11.5pt and missing the test’s y325 safe top by 23.5pt. These remain failure evidence.
