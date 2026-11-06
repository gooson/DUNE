# S04 개편 계획

## Goal

Native 검색 List → Preferred → All Exercises 또는 Results. 기존 equipment SVG와 이름·근육 부제·원래 Toggle을 사용한다. 본문은 세로로 감싸고 Switch 동작·검색·정렬·실제 저장·Watch 동기화는 유지한다.

## Steps

1. 기존 실제 맵과 원래 consumer·데이터 경계를 확인한다.
2. 배치·테마 맵을 구현 전에 저장·검사한다.
3. 기존 native 컨트롤을 보존해 한 화면의 View 표현만 적용한다.
4. 같은 타깃의 S01–S04 증분 컴파일과 정확한 selector를 묶어 실행하고 새 PNG·AX를 검토한다.
5. 독립 소스·Apple UX·품질 리뷰, 해결 문서, 실제 맵 갱신 후 화면별 PR과 통상 머지를 진행한다.

## Test scope

S01 일반/MAX 첫·끝 컨트롤 접근, S02 실제 검색→편집, S03 저장·재진입·확인 취소·MAX, S04 Toggle 상태·화면 재진입. 전체 회귀·실제 iCloud/HealthKit/알림·mock reseed 조작은 이 표현 변경의 검사가 아니다. 현재 전용 iPhone·iPad만 사용하고 Duo는 근거 없는 재시도 없이 미갱신을 명시한다.

## Original source research and risks

# B07 S04 source-only candidate — 2026-11-06

## Frozen baseline

- Worktree: `/Users/shanks/.codex/worktrees/detail-posture-b05/Health`
- HEAD `88c6b1a1d3a3cf14ae9d6a46c68e835ec06cd1bb`; origin/main `94cfa789568edbff7f1825022f02bb9e15bade99`; clean at preparation.
- Target SHA-256 `d4667b920e05f3e8c9f77e66f133a4ebc70fa1556f2bf2fdf90b29130c69b38b`.
- Dependencies SHA-256: `Equipment+View.swift` `6eeda7b91f6b5893d55e1c88d59a6f1e8c0eeb8cf4c5da2805d7a91743ef63b9`; `DesignSystem.swift` `70f3c4908e54c4dfcd8df6089b5ee90e5a355be79042314e9b705238f945e4bf`; `SettingsView.swift` `42a9983a3c378f35d0c2be08b376e7b317268844221bdee3893cf2b37a1ed674`; `Localizable.xcstrings` `d6218b3a9b20fcfca1d0ca848be86062a30ce6301cad021a9e6a6a6eba92acbf`; `TodaySettingsRegressionTests.swift` `5437c69a16a3580d8aa77a25fbb182ab7f99e05c98795476e29090b0884d9ae4`.
- Existing S04 iPhone actual PNG SHA-256 `5f34a3090b7e6ceb7d1c25d540a545e5c65f51bc043e62e5cae9996d3a0b099b`; this historical capture is not evidence of the candidate.

## Source state and visual direction

- S04 opens from `SettingsView.exerciseDefaultsSection`; existing screen uses a native `List`, `Preferred`/`All Exercises`/search `Results`, `@Query` saved defaults, a cached alphabetic exercise library, a per-row native Toggle, and Watch sync in `setPreferred`.
- Existing regular actual S04 shows the first unselected `All Exercises` rows with title, muscle subtitle, and switch. No current per-row equipment icon. iPad, Duo external and Duo internal S04 PNGs exist in actual map; no new capture was made here.
- The one-file candidate adds the existing `Equipment.svgIcon(size:)` asset in a 44pt soft activity-colored tile, semibold exercise name, and wrapping for name and muscle subtitle. It retains the native `List` and Toggle. No new UI strings or catalog keys; no counts, scores, or fixture state.
- `layout-s04.html` and `theme-s04.html` are private draft maps. Before implementation, parent must reconcile them into `docs/design/layout-map/` and `docs/design/theme-map/` (README/index/manifest and builder), then apply source patch. The HTML is a static concept, not native validation or actual capture.

## Apply and verification handoff

1. Check HEAD and the seven dependency hashes; inspect concurrent branch changes. `git apply --check /private/tmp/dune-b07-s04-prep/PreferredExercisesListView.patch` passed against frozen baseline without modification.
2. Copy/adapt both map drafts into repo with official map procedures before app code. Then apply the patch or integrate equivalent one-file edit.
3. Existing exact UI selectors: `DUNEUITests/SettingsSmokeTests/testNavigateToPreferredExercises`, `DUNEUITests/TodaySettingsRegressionTests/testPreferredExercisesSearchShowsToggle`. The latter checks seeded Deadlift search and toggle hit target; neither verifies new icon, max text, favorite relocation or persistence. Add targeted S04 visual/state coverage as needed and run only impact selectors through standard runner.
4. Re-capture changed S04 actual screens on affected iPhone/iPad/Duo devices and sizes per actual map instructions; do not reuse old PNG as proof. Check English/Korean/Japanese names, long translated muscle strings, MAX Dynamic Type, switch hit target, preferred section moving on toggle, search results, and Watch sync behavior.

## Risks

- Equipment SVG in a List row is lightweight but asset availability and icon contrast require native check across themes. Keep `.accessibilityHidden(true)` so Toggle reads the exercise name and muscle text once.
- At MAX text size, 44pt icon stays fixed while names and subtitles wrap. Check switch remains visible and hittable on compact Duo external width.
- A preferred toggle can move the row between native sections; the patch does not change state/index logic. Existing tests do not assert this transition.
- No SDK, simulator, build, repo edit, or actual capture was performed during preparation.
