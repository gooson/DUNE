---
tags: [plan, ios, ipados, duo, activity]
date: 2026-11-03
status: in-progress
---
# A11 운동 일관성 상세 개편

기준: main `df53412c41340861722d422c8da6f4fa0d8e77fd`. Activity 카드에서 진입하는 `ConsistencyDetailView`만 다룬다. T17 건강 질의는 별도 화면이다. 기존 맵 및 테마 표현을 확인하고 [배치 계약](../design/layout-map/activity-consistency-detail-a11.html), [테마 시안](../design/theme-map/themes/dune-consistency-detail-a11.html)을 먼저 마련한다. 예시값은 실제 캡처가 아니다.

현재·최장 연속 일수 및 flame.fill/star.fill, 현재 월 7열 달력·오늘 테두리·운동일·월 목표 진행, 모든 이력 날짜와 일수, 로딩·기존 빈 상태·시스템 뒤로 가기를 보존한다. 개별 운동 20분 이상, 3650일 HealthKit과 수동 기록 병합 및 취소·최신 요청 의미는 기존 VM/서비스를 유지한다. 없는 기간 선택이나 정보 동작을 추가하지 않는다. 팔레트 기반 불투명 카드와 행 아이콘, 넓은 화면 최대 폭 및 접근성 크기 세로 배치를 적용한다.

변경: `ConsistencyDetailView.swift`, `ActivityExerciseRegressionTests.swift`, `Shared/Resources/Localizable.xcstrings`의 정확한 20분 기준 접근성 문구 한 항목, 이 계획과 배치·테마 맵. 기존 시드와 동일한 화면 경로의 normal selector 및 iPad dark MAX selector를 집중 검증한다. 기존 VM/도메인은 변경하지 않으며 검증은 관련 selector만 실행한다. 날짜·월 경계와 앱/테스트 로케일, 접근성 트리 및 내비게이션/탭을 제외한 실제 viewport 프레임을 확인한다. 실제 iPhone/iPad/Duo 접힘·펼침 대상 화면을 새로 캡처하고 실제 디자인맵을 갱신한다. 현재 구현·시안은 실행이나 캡처의 증거가 아니다. 캡처 불가 시 화면 ID와 이유를 기록한다.
# A11 correction proposal — source 30b8647e

Actual closed Duo 30b8647e original two-case run compiled and failed 0/2. Normal case encountered missing `activity-consistency-month-progress`; 005/006 AX records the actual `3/16` leaf with its ancestor `activity-consistency-calendar` ID instead. The history leaf `3 days` and actual date range also inherited `activity-consistency-history`; they would fail later on the existing IDs. Introduce explicit accessibility container semantics on both parents so their actual children can retain own stable IDs. This is a source hypothesis to validate with native AX; it does not change visual geometry, calendar values, history, view model, threshold or workout data.

MAX case failed the initial bounded root reveal after ten swipes, before reaching A11. Actual 002 AX shows selected target `activity-section-consistency` y=10316 and visible root height 678; actual 002 PNG still shows earlier templates. Increase only MAX route reveal to 28 using the existing helper and same `isHittable` contract, keeping normal ten and all failure assertions/timeouts. The first failed run did not execute two-digit MAX test; no geometry pass is claimed.

Run same two original cases once after source review and preservation of failed raw xcresult/host captures. Confirm actual own month-progress/history IDs, actual values/dates, 28 glyph and full frames, Back, normal/MAX native captures and unchanged data. If native AX or navigation differs, diagnose recorded data; do not remove assertions or claim completion.

## A11 MAX correction following be23 native

The be23 original normal selector passed. MAX failed before date checks because day 3 was not materialized in LazyVGrid: host AX 003 exposes weekdays but no calendar day elements while the test asserted existence before scrolling. The helper now performs bounded reveal before the same existence/full-frame assertions and chooses direction from currently materialized day numbers when seeking another lazy cell. All seeded date/value, today, two-digit geometry and Back assertions remain.

The same actual AX reports Monthly Progress 138pt wide and 204pt tall (four caption lines) beside its 77pt icon and 94pt value. Accessibility sizes now stack original icon, label and actual count; normal HStack is unchanged. This corrects source-supported wrapping risk; only new native pixels can establish readable output. No domain, threshold or data change. Retain the failed MAX and the separately passed be23 normal; reuse normal only with explicit unchanged-normal rendering/source closure and no pixel-identity claim. Run only the original MAX selector after source review.

## A11 MAX two-digit day correction following 9e native

9e closed Duo MAX failed on real geometry: day 28 AX text width 25.17pt versus 49.10pt required for its two caption2 digits; the 004 native image shows two-digit days breaking vertically. Accessibility sizes now use a horizontally scrollable seven-column grid with caption2-scaled 24pt base column widths and a visible native scroll indicator. Weekdays and days share the same columns and source date identities; no font cap, model or value changes. Non-accessibility sizes use the same original seven flexible columns and original cell content.

The existing MAX helper retains full date, value, width, single-line and viewport checks, and reveals horizontally outside cells by bounded direction-aware drag within the calendar scroll viewport. Native MAX after this correction is required; 9e MAX remains failed. Previously passed be23 normal can be reused only under independently reviewed same-normal-source closure, not as fresh current capture.

## Singular history copy after native review

The 3c MAX and earlier be23 normal captures contain historical English `1 days` for a one-day history row. Current source uses a localized singular only for `period.days == 1` (en `1 day`, ko `1일`, ja `1日`); other counts retain the existing formatter and localization. Previous actual captures keep their original source and known singular-copy P3; source reuse covers unaffected layout/data only and excludes changed English singular text. New normal captures should show the updated copy. MAX glyph/layout evidence from 3c remains historical source evidence, not a fresh current-source screenshot. No workout, threshold or streak calculation changed.
