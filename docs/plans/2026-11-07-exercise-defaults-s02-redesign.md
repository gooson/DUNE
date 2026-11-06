# S02 개편 계획

## Goal

Native 검색 List → 원래 Configured → All Exercises. 기존 운동 activity 심볼과 이름·실제 기본값·원래 별/핀을 보존한다. 원래 정렬·검색·편집 목적지와 저장 데이터는 유지한다.

## Steps

1. 기존 실제 맵과 원래 consumer·데이터 경계를 확인한다.
2. 배치·테마 맵을 구현 전에 저장·검사한다.
3. 기존 native 컨트롤을 보존해 한 화면의 View 표현만 적용한다.
4. 같은 타깃의 S01–S04 증분 컴파일과 정확한 selector를 묶어 실행하고 새 PNG·AX를 검토한다.
5. 독립 소스·Apple UX·품질 리뷰, 해결 문서, 실제 맵 갱신 후 화면별 PR과 통상 머지를 진행한다.

## Test scope

S01 일반/MAX 첫·끝 컨트롤 접근, S02 실제 검색→편집, S03 저장·재진입·확인 취소·MAX, S04 Toggle 상태·화면 재진입. 전체 회귀·실제 iCloud/HealthKit/알림·mock reseed 조작은 이 표현 변경의 검사가 아니다. 현재 전용 iPhone·iPad만 사용하고 Duo는 근거 없는 재시도 없이 미갱신을 명시한다.

## Original source research and risks

# B07 S02/S03 private preparation

Status: design and patch candidates only. Source commit `88c6b1a1d3a3cf14ae9d6a46c68e835ec06cd1bb`; repository clean when prepared. No SDK, simulator, build, app capture, or repository edit was performed. The HTML files are direction mockups, not actual app captures.

## Source and baseline

- S02: `DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift`; target SHA-256 `8faee9c9fedfc9963405ec4b689cb41862c52aa9e359e012f512794b77515a9b`.
- S03: `DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift`; target SHA-256 `b6693291042025ecfa39f6073b7165ef2d9510194fd858f9bebc75d992c835f7`.
- Entry route: `DUNE/Presentation/Settings/SettingsView.swift` SHA-256 `42a9983a3c378f35d0c2be08b376e7b317268844221bdee3893cf2b37a1ed674`. It owns the navigation link to S02. S02 has the links to S03; neither target owns a root NavigationStack.
- Exercise metadata: `DUNE/Domain/Models/ExerciseDefinition.swift` SHA-256 `eeb2e5d77edc0dcfdb0276799d2468df339293b3dc2fd2c0cdb44b74c7e3053f`; `resolvedActivityType.iconName` is already used in exercise UI. Candidate uses the existing activity icon, with the existing star and pin status symbols preserved.
- Existing regression selectors: `DUNEUITests/Full/TodaySettingsRegressionTests.swift` SHA-256 `5437c69a16a3580d8aa77a25fbb182ab7f99e05c98795476e29090b0884d9ae4`.
- Current actual captures: regular S02 SHA-256 `7f6f63511ff57246a5a7a8c35b50476299243f63c05e12b3b3afb8f0d7b357fd`; regular S03 SHA-256 `9f633664c794abbc2d0b357b19386e91bd206b51303b08595170555a733aac4a`. Reviewed as baseline. Other device captures exist under `docs/design/phone-design-map/actual/{ipad,duo,duo-open,watch}/images/S02.png` and S03.png.
- Theme dependency: `DUNE/Presentation/Shared/Components/ScoreHeroPalette.swift` SHA-256 `1108dab94c71c335f0ff14b92cb70d40903409671138404f5c6aa4865638c408`; candidates do not depend on this palette. S02 uses existing `theme.accentColor` and DS spacing/radius tokens.

## S02 candidate

Files: `S02/ExerciseDefaultsListView.swift`, `S02.patch`, `S02/direction.html`.

Keep the native `List`, `Section`, `ForEach`, searchable control, configured-first and alphabetical all-exercises behavior, saved-default lookup, status icons, row identifiers, and links. Add one 28-point existing activity symbol before each exercise name in the row. The lightweight glyph has an accent tint/background and is hidden from accessibility because the text names the exercise. No per-row `StandardCard`, summary, data or persistence change.

Potential risk: adding a glyph can narrow long exercise names on compact phones and at larger text. Check actual iPhone/iPad/Duo variants, long Korean and Japanese names, VoiceOver row label and scroll performance. The existing `List` virtualization remains.

## S03 candidate

Files: `S03/ExerciseDefaultEditView.swift`, `S03.patch`, `S03/direction.html`.

Keep the native `Form`, all labels, original SF Symbols, text field bindings, kg/reps semantics, number keyboards, toggles, Save, clear confirmation, model writes, Watch sync, and back navigation. Use the same horizontal input rows at ordinary text sizes with a conditional Spacer between each label and the trailing 80-point field. At accessibility text sizes the Spacer is absent and the label stacks above its full-width field. Fields keep their identifiers and right alignment. No new string keys or validation edits.

Potential risk: `AnyLayout` helper needs a target compile, and the actual Form row fit and keyboard behavior need UI verification at maximum Dynamic Type. Do not infer a successful run from this prep.

- S03 candidate SHA-256: full Swift file `92f215f4a2b3a94ca474e5bd61cc8585f900e8a75d9c02bf21c98dd2d9e6a080`; patch `55a00342b3dbf7c04e079d76c116dbd769fce171e50f87a6e46d39f2271ab0b4`. The source guard remains `b6693291042025ecfa39f6073b7165ef2d9510194fd858f9bebc75d992c835f7`.

## Map and verification handoff

Before applying app patches, create or update S02/S03 layout maps under `docs/design/layout-map/` and link them from its index, then update theme direction artifacts only if the theme is intentionally changed. The HTML direction files here are inputs to that map work and must not be marked as actual captures. After implementation, recapture affected S02/S03 device and state variants in the actual phone design map.

Relevant existing focused UI selectors:
- `DUNEUITests/TodaySettingsRegressionTests/testExerciseDefaultsListSearchesAndOpensEditRoute`
- `DUNEUITests/TodaySettingsRegressionTests/testExerciseDefaultEditClearsSavedValues`

Add targeted checks for S02 search/filter/order/long names and S03 Save, Cancel/back, toggle persistence, kg/reps and maximum Dynamic Type only where current tests leave the changed behavior unverified. Run via the standard UI wrapper with a single owned simulator after the current B06 run finishes. Do not rerun unrelated P03/H08 work.

Apply each patch only after rechecking its target SHA-256 and current branch. Patch files use repository-relative `a/` and `b/` labels; the full candidate files are easier to review.
