# S01 개편 계획

## Goal

Native Form → 운동 기본값 → Live Activity → 운동별 설정 → 알림·브리핑 → 테마 → 데이터·개인정보 → 정보. 안전 영역을 중복 가산하지 않고 DS 간격과 system-primary 섹션 제목을 사용한다. 기존 모든 컨트롤·값·아이콘·동작은 유지한다.

## Steps

1. 기존 실제 맵과 원래 consumer·데이터 경계를 확인한다.
2. 배치·테마 맵을 구현 전에 저장·검사한다.
3. 기존 native 컨트롤을 보존해 한 화면의 View 표현만 적용한다.
4. 같은 타깃의 S01–S04 증분 컴파일과 정확한 selector를 묶어 실행하고 새 PNG·AX를 검토한다.
5. 독립 소스·Apple UX·품질 리뷰, 해결 문서, 실제 맵 갱신 후 화면별 PR과 통상 머지를 진행한다.

## Test scope

S01 일반/MAX 첫·끝 컨트롤 접근, S02 실제 검색→편집, S03 저장·재진입·확인 취소·MAX, S04 Toggle 상태·화면 재진입. 전체 회귀·실제 iCloud/HealthKit/알림·mock reseed 조작은 이 표현 변경의 검사가 아니다. 현재 전용 iPhone·iPad만 사용하고 Duo는 근거 없는 재시도 없이 미갱신을 명시한다.

## Original source research and risks

# B07 S01 Settings preparation

Status: source-only candidate, not applied to the repository; no SDK or native capture ran. The HTML files are static proposals and are not app evidence.

## Baseline and dependencies

- Worktree: `/Users/shanks/.codex/worktrees/detail-posture-b05/Health`, frozen source `88c6b1a1d`; worktree was clean when prepared.
- Target `DUNE/Presentation/Settings/SettingsView.swift`: SHA-256 `42a9983a3c378f35d0c2be08b376e7b317268844221bdee3893cf2b37a1ed674`.
- `Components/NotificationSettingsSection.swift`: `0f0b09b83d4f060d123635f307102d1d1518e0ec2cefd7208fe22f2616c55b22`.
- `Components/ThemePickerSection.swift`: `b4a24b6308831d3750f215c0dc9e1cd38891ddab1e232f4462f979b60fa83a4e`.
- `Presentation/Shared/DesignSystem.swift`: `70f3c4908e54c4dfcd8df6089b5ee90e5a355be79042314e9b705238f945e4bf`.
- `DUNEUITests/Full/TodaySettingsRegressionTests.swift`: `5437c69a16a3580d8aa77a25fbb182ab7f99e05c98795476e29090b0884d9ae4`.
- Existing actual regular iPhone S01 PNG: `6a9e7f7bf9946f1816267c646f7dd2059bf07b9fe2565e260cb9671c143fc64f`. It shows a large blank region below the navigation bar; it predates this candidate.
- Candidate file: `SettingsView.swift`, SHA-256 `565cb84ed3fb057b6e08ca0fad9ba60dfbb2a1611b4e1a8aaf46d976a01390ce`. Patch: `SettingsView.patch`, SHA-256 `cb1e0595859f214ba396284bb2ebbbfbebe8ea881f23bab8913fc9d5ce7f9558`.

## Intent

1. Remove `GeometryReader` from around native `Form`. Its top margin adds `safeAreaInsets.top` inside a scroll view that already respects the safe area; replace it with one DS top spacing token. Keep horizontal and bottom margins at DS spacing. This should bring the first section closer to the navigation bar without changing row controls.
2. Give each local section heading the same semibold, system-primary treatment through `settingsSectionHeader(LocalizedStringKey)`. Reuse existing English keys and catalog translations. The nested `NotificationSettingsSection` keeps its own established styling and all of its behavior.
3. Set explicit section spacing with DS token. Keep `Form`, native Stepper, Picker, Toggle, NavigationLink, Button, section footers, original icons, values, identifiers, and all action closures. No per-row `StandardCard` or eager custom list.

## Map proposal order

1. Before applying the Swift candidate, add the proposed S01 layout page under `docs/design/layout-map/`, link it from that map's index/README, and adapt `settings-s01-layout-proposal.html` to the repository design-map format.
2. Add the proposed DUNE light/dark expression under `docs/design/theme-map/themes/`, register it in `manifest.json` and README, run the theme-map builder/check. `settings-s01-theme-proposal.html` is a starting draft; its simulated control glyphs are illustrative, not replacements for native controls.
3. After source implementation and focused UI validation, recapture affected S01 regular iPhone, iPad and Duo closed/open actual images and update `docs/design/phone-design-map/actual/` with fresh provenance. Do not relabel the existing PNGs as new evidence.

## Focused validation candidates

- Build: standard iOS build for `SettingsView` compile and `Form` modifier availability.
- UI: `DUNEUITests/Full/TodaySettingsRegressionTests/testSettingsShowsPhaseTwoRows` (top row, stepper increment/decrement, full-list reachability, lower sections and back-to-top visual audit).
- UI: `DUNEUITests/Smoke/SettingsSmokeTests/testSettingsLoads` and `testBedtimeReminderSettingsExist` if changed section spacing affects notification rows.
- UI: `DUNEUITests/Visual/ContourThemeTests/testThemeSwitchPersistsAcrossLaunch` only if theme picker appearance or selection is affected in native review.
- Manual/native capture: S01 top and bottom, default and maximum Dynamic Type, light/dark, iPhone and affected iPad/Duo orientations. Check native Form section header treatment, iCloud/permission actions, mock section in simulator, and actual settings values.

## Risks and limits

- The existing screenshot alone cannot prove that safe-area addition is the sole source of the blank region. A native capture must confirm the top inset after applying the candidate.
- `Form` controls section header casing and inset on each OS; the proposed helper may be restyled by the system. Inspect native output at default and maximum Dynamic Type, including Korean/Japanese labels.
- Removing explicit geometry safe-area additions may change the inset on Duo or iPad. Confirm the first and last rows remain clear of navigation and home areas.
- `NotificationSettingsSection` is outside this one-file candidate, so its heading may retain a native weight while local headings become semibold. Assess the combined page before accepting.
- No new string catalog key is required. The candidate does not change stored preferences, theme choices, data values, or navigation destinations.

## Final scoped result

iPhone 일반·MAX와 iPad 일반의 첫/끝 행 접근 및 기존 Stepper 왕복이 통과했다. 새 일반/MAX PNG·AX를 독립 검토했다.

[PNG/AX and original run counts](../design/full-redesign-map/review/settings-s01-2026-11-07/index.html). Mixed B07 suite not green; remaining capture limits are explicit. S03 remains held.
