# A12 Exercise Mix detail redesign

Base: `4fb32ead94df9c0bc595cf744271d1003832030d`. Approved browser direction: `refs/codex/snapshots/f6123bb0dce51eb02ac8fecddbc9345965b70d50:docs/design/detail-redesign-map/manifest.json` A12 (proposal fixtures, not app data). Actual source `ExerciseMixDetailView.swift` takes precedence for supported behavior; the prototype's info button, state tabs and weekly interaction are not existing A12 actions.

## Scope

Preserve 4-week date range, workout-record total, category counts and percentages, weekly stacked segments and dates, muscle sets/shares and unattributed disclaimer, cardio counts/duration/distance, selectable top-eight donut and complete frequency list, HealthKit partial-data notice, loading/empty states, and native Back. Preserve existing data, calculations, service, navigation and source icons/colors. The current view has no period selector. Use an opaque theme-aware summary hero and clearer rows; keep charts using real source data. Accommodate accessibility sizes through explicit single-column layouts.

Files: `DUNE/Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift`, its focused UI selector if meaningful geometry/value checks are needed, layout/theme proposals and generated theme index. No VM/domain changes.

## Validation still required

Source checks and `git diff --check` only during preparation. Product compile and focused `ActivityExerciseRegressionTests/testActivityExerciseMixRouteOpensExpectedScreen` must be run later using the owned standard runner. Verify actual normal iPhone, iPad and Duo closed/open plus relevant MAX/Dark geometry, selectable donut, actual counts, dates, units and Back. New A12 actual-map captures for each affected tier are required; historical images cannot stand in for after captures. Review accessible text and layout with real data before claiming native quality.

Risks: category and donut colors have meaning; text wrapping and chart selection behavior must survive accessibility sizes. Empty, partial-data, unattributed, zero-denominator and truncated top-eight distribution paths must retain exact existing semantics.

Source test preparation adds a normal/MAX shared route with positive actual totals, full visible leaf frames, weekly/muscle/cardio checkpoints, a real off-center donut tap and selected name/count, frequency leaf and native Back. Seeded total is intentionally not hard-coded because HealthKit and manual records are merged. The selector, gesture and AX hierarchy remain unverified until native execution.

The focused route cross-checks the displayed category counts against the displayed total, the source window (today minus 27 days through today), and the chosen donut item against its keyed full-frequency row. Existing `ExerciseMixServiceTests/emptyAndCutoff` and `mergedSources` cover the unchanged cutoff and merged-source/weekly totals; reuse or run those exact unit selectors separately if needed. No seeded total is assumed. All native output and format/gesture assumptions remain unverified.

A11 normal native AX showed a parent identifier propagating onto its child leaves in the same SDK. A12 weekly, muscle and cardio cards now explicitly contain accessibility children to reduce that source-level risk; A12 hierarchy and VoiceOver behavior remain unverified. The repeated weekly total, muscle set and cardio count identifiers intentionally select a representative first actual leaf; only the separately keyed frequency rows are used for an exact selected-item comparison.

A11 실제 MAX 실행에서 Activity의 하단 링크까지 10회 스와이프로 도달하지 못했다. A12는 그 아래에 위치하므로 최초 실행 전 MAX 경로 탐색만 최대 32회로 한정하고 일반 크기는 12회를 유지한다. 링크가 보이면 즉시 중단하며 모든 화면 값·날짜·전체 프레임·선택·Back 검사는 그대로 유지한다. 이는 A12의 실제 통과를 의미하지 않는다.

## 실제 첫 검사의 차트 프레임 수정

5e047c04 접힘 Duo 일반·MAX 실행은 실제 0/2 실패다. 두 검사 모두 같은 차트 식별자의 664×538pt 접근성 컨테이너를 선택했다. 실제 플롯은 같은 식별자의 326×200pt 요소이며 소스가 지정한 200pt 높이와 일치한다. 테스트는 표시 영역에 맞는지와 무관하게 양의 면적이 가장 작은 차트 프레임을 선택한 뒤 높이 200pt와 전체 표시 영역 포함을 계속 검사한다. 가까운 플롯은 짧은 수직 드래그로 찾으며 날짜·합계·선택 값·전체 목록·뒤로 가기 검사는 보존한다. 앱 소스는 변경하지 않는다. 실제 실패 원본·접힘 전후 상태·복사 중 공간 부족과 복구 기록은 모두 보존했고, 수정본은 별도 네이티브 실행으로 확인한다.
