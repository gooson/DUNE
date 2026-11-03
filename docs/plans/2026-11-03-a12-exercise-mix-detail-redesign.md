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

## 조각 선택 검증과 값 단위 교정

c6의 실제 일반·MAX 검사는 200pt 차트 전체 표시를 통과한 뒤 조각 선택에서 0/2 실패했다. 여덟 개의 같은 크기 조각에서 테스트의 오른쪽 수평 탭은 실제 흰색 경계에 놓였다. 테스트는 실제 전체 빈도 목록의 상위 여덟 값에서 첫 두 조각의 중간 각도를 계산해 서로 다른 이름·횟수를 확인한다. 제품의 기존 누적 360도 비교는 원시 횟수 누적 비교로 교정한다. Apple ChartProxy의 데이터 값 설명과 SectorMark 정규화 자료에 근거한 단위 추론이며, 두 조각의 네이티브 선택으로 확정해야 한다. 단위 테스트는 서로 다른 횟수와 경계·빈 값·잘못된 값·호출자가 전달한 범위를 검사한다. 원래 데이터 조회·빈도·운동 계산은 변경하지 않는다. 기존 두 실행 실패와 raw 결과를 유지하고 사용자 자율 진행 지시에 따라 이 원인에 대한 필요한 검증 한 번을 별도 연결 기록으로 추적한다.

공식 근거: https://developer.apple.com/documentation/charts/chartproxy 및 https://developer.apple.com/videos/play/wwdc2023/10037/ .

## 한정된 선택 제스처 진단 · 발행 전 제거

547의 일반·MAX는 조각 내부 탭 뒤 선택 이름이 없어 실제 0/2 실패다. 값 변화가 없었는지 일시적으로 생겼다가 해제됐는지 아직 구분하지 못한다. 한 번의 일반 크기 진단에서 DEBUG 명시 플래그가 있을 때만 실제 onChange 값과 준비 신호를 OSLog로 남기고, 측정한 차트 프레임의 창 기준 좌표로 짧은 탭과 두 번의 1초 누르기를 비교한다. 레이아웃·접근성·hit testing·제스처는 변경하지 않는다. 진단 실행 완료는 기존 기능 검사 통과가 아니다. 동일 앱 PID·시간·준비 신호를 결합하지 못한 로그는 불확실로 남긴다. 진단 코드·메서드·플래그는 Ship 전에 제거하고 실제 기능 게이트를 별도로 확인한다.

## 실제 진단 결과와 읽을 수 있는 선택 상태

50e의 단일 일반 진단은 실행 완료 1/1이며 기존 기능 통과를 의미하지 않는다. 동일 앱 PID·준비 신호·시간을 결합한 원본 로그에서 첫 두 길게 누르기의 원시 값 약 0.5/1.5가 실제 첫 두 운동과 일치했고 각각 손을 떼면 nil로 돌아갔다. 실제 자료는 별도 보존했다. 진단용 OSLog와 메서드·분기를 모두 제거했다. 기본 길게 누르기는 유지하고 손을 뗀 뒤 정보가 남도록 했으며 차트 아래 선택 해제 액션으로 원시 값·선택을 함께 해제한다. 선택 액션은 차트 아래에 있어 누르는 도중 플롯 원점이 바뀌지 않는다. 기존 end 변경 기반 다시 불러오기에서 선택을 초기화한다. 상위 8개 차트와 전체 합계를 설명하고 en/ko/ja 문구를 추가했다. 실제 두 조각 이름·횟수, 해제 뒤 전체 합계와 Back을 기존 일반·MAX 검사에서 확인한다. VM·단위 테스트 내용은 547의 실제 4/4와 동일해 재실행하지 않는다. 기존 실패 이력과 진단 한계는 모두 유지하며 기능 게이트는 새 제품 코드에서 별도로 확인해야 한다.

최종 좁은 Duo MAX 케이스에는 기존 테스트용 dark 스타일 인자를 함께 적용한다. 동일한 한 케이스로 최대 글씨와 어두운 앱 화면을 확인하며 일반 네 프로필은 밝은 상태를 유지한다. OS 준비 상태의 light와 앱의 명시적 dark 스타일은 구분해 기록한다. 기능·값·선택·해제 검사는 동일하다.

### MAX execution budget correction

The 5f mixed run remains failed: the normal case individually passed (202.657 seconds), while MAX reached clear selection but exceeded its default 300-second allowance before completed Back. Only the exact MAX case receives 360 seconds before superclass setup; normal setup, test assertions, app, data model, catalog and standard executors are unchanged. Retain all original failures and parser limitations, independently bind the historical normal source closure, then run the original MAX selector alone. No repeated user approval is required under the latest autonomous-validation instruction.

### Native readability correction

6706 closed MAX and open normal passed their original functional contracts. Independent review of the real MAX PNG/AX found adjacent count/percentage and weekly label/count text visually ambiguous. Four decorative, accessibility-hidden centered dots distinguish these values without changing data, IDs, fonts, icons or catalogs. Preserve the pre-correction results as history; final captures must use the corrected app source, with closed normal/MAX and open/phone/iPad normal verification.
