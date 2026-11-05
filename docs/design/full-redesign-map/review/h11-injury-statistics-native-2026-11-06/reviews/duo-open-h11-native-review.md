# H11 Duo open native review

**Scope:** Independent review of H11 Injury Statistics in the fresh Duo open, English/Light normal-text archive at source `2d1656bb83a3a41ce02e1c41352769e0a867b032`. The owned simulator was `081F5764-D395-45A7-9ABE-A6AFE879F4A6`; hinge angle readback was `180.0` before and after. The active display is the `2007x2853` PNG file (internal image size `2853×2007`); the `1398x2034` display is black. Four selected H10/H11/H12/H13 SDK methods passed with no skips or failures, but this review judges **H11 only**. Exact actions, PNG/AX paths, and SHA-256 values for checkpoints 030–033 are in [duo-open-h11-native-review.json](duo-open-h11-native-review.json).

## Finding

- **P3 — chart category labels touch horizontal plot rules.** At 030–031 the `Shoulder` and `Knee` names sit over the horizontal grid rules at the top of each bar row. Both names, their `1` values, the orange bars, and the `0–1` scale remain readable. AX exposes separate `Shoulder` and `Knee` chart elements, each with value `1`. This is chart polish, not a missing metric. It matches the previously observed normal/closed chart placement issue.

No P1/P2 native finding in the selected H11 open checkpoints.

## Evidence readback

| Checkpoint | PNG/AX observation |
|---|---|
| 030 · overview | `Injury Statistics` and `Overview` visible; Total **2**, Active **1**, Avg Recovery **10d**, Longest **10d**. The orange chart and text summary `Shoulder: 1` / `Knee: 1` are also in the viewport. AX has matching four value IDs and `injury-statistics-frequency-chart`. |
| 031 · frequency graph | Both bars and names remain fully within the active display; AX chart children have value `1` for Shoulder and Knee. No hero/card/control overlap or horizontal truncation seen. |
| 032 · Back | AX has `injury-history-screen`, both fixture rows, and no `injury-statistics-screen`. |
| 033 · before teardown | PNG shows Injury History with active Knee and recovered Shoulder; AX again has `injury-history-screen` and both rows. |

The overview uses dark ink on light cards and the Active value remains legible in its brown tint. Icons and chart marks match the supplied fixture; no fabricated measurement is visible. Source, screenshot, and AX were inspected read-only. This evidence does not establish Dark appearance, other locales, MAX Dynamic Type, VoiceOver traversal, or other device states.

**Archive:** `.codex-checks/batch01/evidence/duo-open-2d1656bb-passed/{execution-metadata.json,summary.json,result.json,host/checkpoints.jsonl,host/angle-before.txt,host/angle-after.txt,host/030–033-2007x2853.png,host/030–033-hierarchy.txt}`.
