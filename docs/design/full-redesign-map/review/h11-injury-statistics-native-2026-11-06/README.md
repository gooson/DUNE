# H11 Injury Statistics — native capture evidence

All agreed selected screen methods and scoped native reviews are complete: normal iPhone, iPad, Duo closed/open, plus Duo closed MAX. English, Light; normal text on four profiles and MAX only on closed Duo. The selected pairs are checkpoints, not separate tests.

Selected PNG/AX pairs: 15. Historical pairs: 0. H09 follow-up pairs: 0. Every selected pair has an archive, source revision/file SHA, device UID, fixture, action, PNG/AX path and SHA-256 in `capture-manifest.json`.

Independent native reports are listed in `native_review_reports`; all required screens have P1=0/P2=0. Preserve their P3 notes and explicit scope limits. The source/method closure is [source-closure.json](source-closure.json) (19 distinct positive method/profile combinations contributing 20 screen states across H10–H13).

H11/H12/H13 App and fixture source hashes match the final target even where a passing capture predates `04e2ec0ad`. The first iPad four-method archive was partial because H10 failed; only the passing method for this screen is selected. H12/H13 share one Duo closed MAX test method, counted once across the batch.

Historical failed, compile, timeout, and pose preflight attempts remain linked in the manifest. No full CI, Dark, other language, VoiceOver traversal, other devices or PR completion is claimed; GitHub tracks merge state separately.

## Independent native reports

- [iphone-normal](reviews/phone-native-review.md) — only the H11 subset is used where a source report covers multiple screens.
- [ipad-normal](reviews/ipad-h11-native-review.md) — only the H11 subset is used where a source report covers multiple screens.
- [duo-closed](reviews/duo-injury-native-review.md) — only the H11 subset is used where a source report covers multiple screens.
- [duo-open](reviews/duo-open-h11-native-review.md) — only the H11 subset is used where a source report covers multiple screens.

[Source and selected-method closure](source-closure.json). Capture sources differ by profile; these are scoped integration results, not a claim that every final PR revision ran the entire suite.

The actual-map index preserves inherited collection metadata, including its prior `last_refresh_*` fields. These describe the historical collection snapshot; updated H11 rows carry the current `source_revision`, device, method and SHA fields individually. They do not assign a single runtime revision to the mixed historical index.
