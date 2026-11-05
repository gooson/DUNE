# Duo closed native review: H10/H11

**Scope:** Independent Apple UX / App Quality inspection of H10 Injury Detail and H11 Injury Statistics only. Archived English, Light, actual closed `0.0` + active LCD evidence from source `6063cf0819ac2a97495b8724edc9b189e0f45759`, simulator `081F5764-D395-45A7-9ABE-A6AFE879F4A6`. Source hashes, every selected PNG/AX pair, and SHA-256 values are in [duo-injury-native-review.json](duo-injury-native-review.json). All four H10/H11 normal/MAX SDK methods passed, including the post-back History state. The separate Sleep MAX method failed; this is **not** an overall Duo profile pass.

## Findings

- **P3 — H11 MAX chart labels cross chart rules.** At checkpoint 033, the large `Knee` and `Shoulder` category labels visually sit on the horizontal plot rules and extend into the plot area. Bars, both categories, counts, and `0–1` scale remain legible, and AX retains `injury-statistics-frequency-chart` in the visible viewport. This is a polish/readability issue at MAX, not lost data. Normal chart at 040 is clear.
- **P3 — H10 MAX status word breaks awkwardly.** The green `Recovered` chip wraps as `Recov-` / `ered` at checkpoints 008–009. The full status remains visible and AX label is `Recovered`. A wider or naturally wrapping treatment would read better on the closed display.
- **P3 — Decorative symbols remain separately announced in AX.** H10 status exposes the symbol image in addition to the status text (for example checkpoint 008 has image `Selected`; checkpoint 021 has `Adhesive Bandage Strip, Filled`). This may cause redundant VoiceOver speech. VoiceOver traversal was not run, so this is an AX tree observation only.

No P1/P2 native finding in the reviewed H10/H11 checkpoints.

## Evidence readback

| Screen/state | Selected checkpoints | Observed result |
|---|---|---|
| H10 MAX | 008–013, 015 | Shoulder/right/moderate/recovered hero, 10 days, severity guidance, timeline dates, recorded date, and recovered memo are reached across the scroll; checkpoint 015 shows `injury-history-screen` after Back. |
| H10 normal | 021–025, 027 | Knee/left/minor/active, 5 days, dates and memo visible; edit form has Cancel/Save, then returns to detail; checkpoint 027 shows `injury-history-screen` after Back. |
| H11 MAX | 031–033, 035 | Overview values 2 total, 1 active, 10d average, 10d longest, then frequency chart with Knee 1 / Shoulder 1; checkpoint 035 shows `injury-history-screen` after Back. |
| H11 normal | 039–040, 042 | All four overview metrics and chart visible in compact layout; checkpoint 042 shows `injury-history-screen` after Back. |

On the active `1398×2034` images, content scrolls beneath the fixed system rail without an observed horizontal cut or control overlap. The `2007×2853` inactive LCD images are black and were excluded from visual judgments. The MAX chart screenshot starts mid-scroll, so its clipped heading at the top edge is expected scroll position rather than a layout truncation. Actual gesture/touch reach is supported by the passing named SDK methods; manual VoiceOver, Dark appearance, other locales, and other device states remain unverified by this artifact.

**Source and limits:** `.codex-checks/batch01/evidence/duo-closed-6063cf08-retry-partial/{execution-metadata.json,result.json,host/checkpoints.jsonl,host/NNN-1398x2034.png,host/NNN-hierarchy.txt}`. This review did not run the simulator or change app source.
