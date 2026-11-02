# PR885 Phone and iPad native quality

## Summary

One reviewer applied SwiftUI, Apple UX and UI-test-expert lenses to actual T13 native images; this is one reviewer, not three agents. Actionable P1/P2/P3 findings:0. No UI testing issues found in this bounded scope. No runtime performed.

Manifest-backed evidence: historical iPhone18 Pro Max original734db23d normal+darkMAX2PASS, folder `ui-phone-unavailable-current`; fresh parent-reported iPadPro13-inch(M5) normal1PASS at validation3fac15d4, folder `pr885-ipad-unavailable-final-2026-11-02`. Both under validation `.codex-checks/t13/evidence`. Read manifests and exact normalBE8FDC78, MAXtitleDD3D2EDA, GoBack71486827, IDend2A898B85 and fresh iPad781055A4 PNGs.

## Findings

None.

## SwiftUI lens

Phone normalBE8FDC78 shows original branch symbol, complete two-line title, wrapped full explanation, distinct full-width Go Back and UUID footer in normal vertical flow. Horizontal card/button edges align; footer is outside hero content rather than overlaid over text. No clipping/overlap established.

DarkMAXDD3D2EDA shows complete enlarged title and multiline explanation within horizontal card bounds. Lower action extends below the initial viewport, which is intended scroll continuation. GoBack71486827 is a later viewport with the action fully visible and separate from the native tabs. IDend2A898B85 shows wrapped complete UUID footer below the button with no horizontal truncation. The title, long explanation, action and footer are verified at separate scroll checkpoints; this is not a claim they fit simultaneously at maximum size. Secondary footer is deliberately visually subordinate; no quantitative contrast certification is made.

iPad781055A4 is the verified unavailable-detail state before Back. Full original title and explanation, prominent Go Back and actual UUID are visible within the centered560pt column. Card/action/footer alignment and margins remain clear and do not stretch across the whole iPad. No actionable layout defect was established. Large-image tool presentation alone was not used to infer transient rendering defects.

## Apple UX lens

The original meaning is preserved: identify unavailable destination, explain it, offer the explicit Go Back recovery action, then show the actual technical identifier as subordinate detail. The branch symbol retains its original role and is hidden from AX in source; meaningful title is a header. Product Go Back is separate from standard native navigation. Normal/dark captured typography and wrapping support readable recovery content; no invented route/action/date/status appears. No VoiceOver session, contrast measurement, all-theme approval or arbitrary-content claim follows from these images.

## UI-test-expert lens

Historical normal method verifies title/explanation presence, ID-prefix footer and valid UUID syntax, explicit product Go Back existence, verified-state capture, actual tap and hub return. MAX method additionally checks exact strings, complete title, explanation start/end visibility, whole action/hittability/>=44pt/window containment, whole UUID footer, then reveals/taps Go Back and requires hub return. The source directly interpolates actual itemID; UUID parsing alone is not claimed to prove equality to a separately known fixture ID.

Parent source closure states publicff68 product file equals validation3fac; exact T13 normal/MAX/helper block, relevant generic helper and class launch configuration equal original734/validation. Whole UI-test-file equality is false and not claimed. Thus Phone2PASS is historical unchanged-scope reuse, not new currentHEAD execution. Fresh iPad normalPASS covers its own final method/action path.

Fresh iPad preferred781055A4 is detail-before-Back. C52D57B5 is after product back tap, and679C6416 teardown is hub evidence; neither is a detail after-image. Do not confuse historical Phone679081C8 (different folder/action) with iPad679C6416. Native back/teardown screenshots are not substituted for unavailable-detail readability.

## Missing Test Cases

None newly required for this bounded source change. Duo normal cases remain parent-owned separate work; no Duo or all-device completion inferred. No duplicatePhone, iPadMAX, new unit, Watch or full regression requirement introduced.

## iPad-Specific Risks

Fresh full-size iPad uses native top tabs/sidebar affordance and pushed unavailable view, with its own dismiss action. Sidebar-open/multitasking/rotation/every size class are outside this review. Original iPad baseline group had a bedtime failure while its precise T13 case passed; it must not be labeled whole-groupPASS. The old-stage12EF original belongs to the prior UI family, not the newly redesigned after state. Different original/after device models or viewports must remain explicit in gallery captions.

## Coverage Rating

Adequate for historical Phone normal/darkMAX and fresh normal iPad unavailable-detail recovery behavior, under exact source/test closure. Runtime:authorized available GPT-6.1 Sol medium fallback. No tests/builds/devices/CI/Git/source edits or agents used; only this `/private/tmp` report written.
