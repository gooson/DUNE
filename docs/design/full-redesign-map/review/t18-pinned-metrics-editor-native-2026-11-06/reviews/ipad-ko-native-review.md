# T18 Korean iPad retry native review

Executed source `1ae4fb4c333c0bd8890e91c3fac9d9c355511f3e`, archive `ipad-ko-1ae4fb4c-retry1-passed`: **1 passed, 0 failed, 0 skipped**. The earlier `ipad-ko-d1afd659-first-failed` remains archived as **0 passed, 1 failed**; it was not rewritten as success. Four fresh 1512×2316 PNG/AX pairs and exact SHA-256 values are in the adjacent JSON.

The native modal shows **“주요 지표 6개”** with the original pin symbol and two seeded preview icons, `waveform.path.ecg` and `heart.fill`. HRV `심박변이도` and RHR `안정시 심박수` are both selected. After the List footer materializes, AX and PNG show the full **“오늘 탭 상단에 표시할 지표를 최대 6개 선택하세요.”** without clipping. Cancel dismisses the editor; the title disappears and Today’s pinned edit control remains. No P1/P2 observed.

The executed App screen source SHA matches its earlier English capture; the Shared string catalog **changed bytes**. Its two new manual `%lld` entries provide en/ko/ja title and footer translations. All earlier catalog entries, including the `%@` placeholder keys, are unchanged. The English strings render like the earlier fallback, but historical English captures are not Korean or resource-byte-equivalence proof. This review closes the Korean iPad visual selector only; it makes no gallery publication or full CI claim.
