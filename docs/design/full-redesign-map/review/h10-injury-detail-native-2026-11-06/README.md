# H10 Injury Detail — native capture evidence

All agreed selected screen methods and scoped native reviews are complete: normal iPhone, iPad, Duo closed/open, plus Duo closed MAX. English, Light; normal text on four profiles and MAX only on closed Duo. The selected pairs are checkpoints, not separate tests.

Selected PNG/AX pairs: 35. Historical pairs: 19. H09 follow-up pairs: 4. Every selected pair has an archive, source revision/file SHA, device UID, fixture, action, PNG/AX path and SHA-256 in `capture-manifest.json`.

Independent native reports are listed in `native_review_reports`; all required screens have P1=0/P2=0. Preserve their P3 notes and explicit scope limits. The source/method closure is `.codex-checks/batch01/quality/source-closure.json` (19 distinct positive method/profile combinations contributing 20 screen states across H10–H13).

The earlier iPad row-route failure remains archived. The `04e2ec0ad` fix moved detail route ownership to the stable history view; fresh H10 normal and closed MAX methods passed on all requested profiles. The 19 pre-route H10 image pairs remain under `historical_pairs` and must not be used as final App proof. Four fresh H09 primary history row-list pairs are applied as the scoped actual-map follow-up for the changed row control/chevron.

Historical failed, compile, timeout, and pose preflight attempts remain linked in the manifest. No full CI, Dark, other language, VoiceOver traversal, other devices or PR completion is claimed; GitHub tracks merge state separately.

## Independent native reports

- [iphone-normal](reviews/phone-h10-04-native-review.md) — only the H10 subset is used where a source report covers multiple screens.
- [ipad-normal](reviews/ipad-h10-04-native-review.md) — only the H10 subset is used where a source report covers multiple screens.
- [duo-closed](reviews/duo-closed-h10-04-native-review.md) — only the H10 subset is used where a source report covers multiple screens.
- [duo-open](reviews/duo-open-h10-04-native-review.md) — only the H10 subset is used where a source report covers multiple screens.

[Source and selected-method closure](source-closure.json). Capture sources differ by profile; these are scoped integration results, not a claim that every final PR revision ran the entire suite.
