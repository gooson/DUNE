# H09/H10 iPad route retry native review

**Scope:** Independent read-only review of the H09 History row and H10 Detail route at source `04e2ec0add31d110734452d854767a25407b7eca`, iPad mini (A20 Pro), English/Light, normal text. The exact failed selector from the earlier iPad run, `testInjuryHistoryRowOpensDetailAndEditForm()`, now **passed 1/1 with no skip**. This new pass does not erase the older `ipad-2d1656bb-partial-failed` archive (3 pass, 1 H10 fail); both source states remain distinct. [Evidence inventory](ipad-h10-04-native-review.json) lists 13 named PNG/AX pairs with SHA-256 and the archived source hashes.

## Findings

- **P3 — redundant status symbol in AX remains.** The H10 status text and its decorative symbol are separate AX elements (`Active` plus `Adhesive Bandage Strip, Filled`; later `Recovered` plus `Selected`). The text status is complete and visible. This was present in earlier H10 evidence and is unrelated to the row route fix; VoiceOver traversal was not run.

No P1/P2 or new route-specific native finding in the reviewed iPad evidence.

## Evidence readback

| State | Native PNG and AX observation |
|---|---|
| H09 before first tap | Active Knee and recovered Shoulder rows show original severity symbols, body part, side, severity, duration, date and Active badge. The new right chevrons are aligned at the far edge. AX exposes full-width Button frames (`716×88.5` pt), `injury-history-row-0/1`, and complete row labels. |
| First tap / H10 | The capture immediately after tapping `injury-history-row-0` shows `Injury Detail`. Summary and AX have Knee / Left / Minor / Active / 5 days. The timeline and memo are visible within the same scroll: start Nov 1, ongoing end, recorded date, and “Mild pain during squats”. |
| Edit and Save | The native Edit Injury sheet appears with Cancel/Save. Saving returns to the same detail route and retains its fields and Mark Recovered action. |
| Mark Recovered | One action changes the open H10 detail status to `Recovered`; its `injury-detail-screen` remains present, the memo/timeline remain, and `injury-detail-mark-recovered` disappears from AX. The image shows the green recovered label and no recovery toolbar action. |
| Back to H09 | Back returns to Injury History. Only the Recovered section remains, containing Knee and Shoulder. Knee's AX row has no `Active` and shows the ended `11/1 ~ 11/6` range; both row Buttons retain their IDs and labels. The before-teardown pair confirms this state. |

The normal-size layout shows no horizontal clipping, icon/text collision, missing chevron, or overlapping controls on the sampled iPad screen. This is a native PNG/AX finding, not a compile claim. MAX Dynamic Type, Dark appearance, other locales, swipe/context gestures, VoiceOver speech order, and phone/Duo regression after this route change require their own evidence. No Root tracked files, app source, simulator, build, or test were changed for this review.

**Archive:** `.codex-checks/batch01/evidence/ipad-h10-04e2ec0a-passed/{execution-metadata.json,summary.json,result.json,run.xcresult,attachments/}`. Attachment pairs were matched by name and UUID through read-only `xcresulttool get test-results activities` output.
