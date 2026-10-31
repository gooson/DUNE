---
topic: h02-wellness-score-detail-redesign
date: 2026-10-31
status: approved
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-15-wellness-readiness-hourly-detail.md
  - docs/solutions/architecture/2026-02-25-body-score-calculation-card.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
related_brainstorms: []
---

# Implementation Plan: H02 Wellness Score Detail Redesign

## Context

H02의 `DetailScoreHero`는 반투명 중앙 링과 작은 구성 점수 배지를 사용한다. 현재 H01 웰니스 히어로와 병합된 T04 컨디션 상세는 불투명한 테마 표면, `CompactConditionRing`, 읽기 쉬운 상태·근거 계층을 사용한다. H02의 별도 화면 PR에서 이 언어를 잇고 흩어진 기간·추세·요약을 한 카드에 정리한다. 승인 시안 `.codex-checks/prototype-recovery/manifest.json`의 H02 81점과 차트/구성 값은 로컬 예시이며 앱 점수의 근거가 아니다. 기존 조회·계산·조건부 설명을 보존한다.

## Requirements

### Functional

- `WellnessView`의 실제 `WellnessScore`, `ConditionScore?`, `BodyScoreDetail?`, `ScoreRefreshService?` 전달과 `wellness-score-detail-screen`, 영문 고정 navigation title을 보존한다.
- 현재 점수는 `WellnessScore`의 0–100 값·상태 구간·상태 아이콘·실제 `evaluationDate`·서술을 사용한다. 80–100 excellent `checkmark.circle.fill`, 60–79 good `hand.thumbsup.fill`, 40–59 fair `minus.circle.fill`, 20–39 tired `moon.fill`, 0–19 warning `exclamationmark.triangle.fill`. 시안의 excellent 아이콘을 고정하지 않는다.
- 수면 35%, 컨디션 30%, 신체 20%, 자세 15%의 네 **optional** 구성 점수를 보여주고 결측을 0으로 바꾸지 않는다. 원래 `ScoreCompositionCard`와 실제 기여 요인, 조건부 `ConditionCalculationCard`·`BodyCalculationCard`, 전체 계산 설명과 누락 가중치 재조정을 유지한다.
- 실제 `timeOfDayAdjustment`와 `ScoreTimeOfDayAdjustment`의 밤/아침/낮/저녁 projection을 유지하고 `TimeOfDayCard(usesAdaptiveLayout: true)`를 H02 호출부에서 사용한다.
- D/W/M/6M/Y 다섯 기간, 현재 가시 날짜, 차트 스크롤/점 선택, 추세선 전환, 50점 기준선, 실제 요약·하이라이트, 일간 이외 HRV/RHR/수면 하위 추세를 유지한다. 일간은 rolling snapshot만 사용하고 하위 추세를 숨긴다. **비일간 웰니스 과거 추세는 HRV/RHR/수면에 기반한 기존 근사치**이며 당시 신체/자세 네 요소의 실측 이력이 아니다.
- 로딩/차트 없음, 구성 점수 일부 결측, RHR today/latest/baseline/none, 두 계산 카드 부재 등 원래 조건부 상태를 보존한다. H02 ViewModel의 `errorMessage`는 현재 화면에 표시되지 않으므로 이 시각 변경에서 실패 사유를 꾸며 표시하지 않는다.

### Non-functional

- 밝음/어두움 및 테마별 표면의 글자/상태 아이콘 대비를 확인한다. H03에서 관측한 원래 보라색 아이콘/갈색 표면 2.43:1 사례를 반복하지 않도록 불투명 표면에는 `ScoreHeroPalette.ink`/`muted`로 글자를 읽게 한다. 상태 아이콘의 형태를 유지하고 상태색·요인색은 각각 별도 의미로 사용한다. 색만으로 상태를 전달하지 않는다.
- 일반 iPhone, iPad, Duo 접힘·펼침과 최대 접근성 글씨에서 점수·구성·차트·설명이 잘리지 않게 한다. Watch 소비자는 없다. `.claude/**`는 수정하지 않는다.
- 새 문구가 필요하면 `copy-voice` + `.codex/ux-writing.md`, en/ko/ja string catalog 및 `format-xcstrings.swift --check --check-manual` 계약을 따른다. 기존 문구를 우선 재사용한다.

## Approach

H02 전용 private hero를 `WellnessScoreDetailView` 안이나 H02 전용 작은 파일에 둔다. `ScoreHeroPalette`와 `CompactConditionRing`을 재사용해 H01/T04와 맞춘다. 실제 상태 아이콘, 평가 시각, 네 optional 구성 점수를 넣고 접근성 큰 글씨에서는 링 대신 외부 숫자와 세로 근거를 표시한다. `DetailScoreHero`, 전역 팔레트, `WellnessScoreDetailViewModel`, scoring use case는 변경하지 않는다.

기존 기간 Picker, `ScoreDetailChartHeader`, `DotLineChartView`, 요약을 **하나의 `StandardCard`** 안에 배치한다. 차트 스크롤·점 선택과 현재 range 표시를 보존한다. T04의 이전/다음 버튼은 H02 ViewModel에 `stepVisiblePeriod`/`canStep*` 계약이 없으므로 추가하지 않는다. 하위 추세와 계산 내용은 그대로 둔다. 한 native disclosure는 조건부 계산 카드와 모든 설명 항목을 담고 44pt 조작/VoiceOver를 증명할 때만 적용한다; 그렇지 않으면 현재 공개된 카드를 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 공유 `DetailScoreHero`를 전역 변경 | 코드 재사용 | Training Readiness 등 H02 외 화면과 대비/배치가 바뀜 | 제외 |
| 시안 수치/일별 점수를 직접 삽입 | 빠른 외관 일치 | 실제 건강 기록과 충돌, 과거 4요소 점수로 오인 | 제외 |
| H02 전용 hero + 기존 데이터 컴포넌트 재배치 | 화면 범위 작고 원래 데이터 유지 | H02 로컬 코드 추가 | 채택 |
| T04 기간 이전/다음 API를 H02로 확장 | 명시적 이동 | ViewModel·차트 계약 변경과 별도 검증 필요 | 이번 PR에서 제외 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/design/layout-map/h02-wellness-score-detail-proposal.md`, `docs/design/layout-map/index.html` | add/modify | H02 상태·배치·폭·문구 기준과 링크를 구현 전에 등록 |
| `DUNE/Presentation/Wellness/WellnessScoreDetailView.swift` | modify | 전용 불투명 hero, adaptive TimeOfDay, 통합 추세 카드, 조건부 설명 보존 |
| `DUNE/Presentation/Wellness/Components/WellnessDetailHeader.swift` | optional add | View가 커질 때만 H02 전용 hero 분리; project registration 필요 |
| `DUNEUITests/Full/WellnessScoreDetailRedesignTests.swift` | add | 실제 seeded score/구성·기간·추세·설명·최대 글씨의 좁은 계약 |
| `Shared/Resources/Localizable.xcstrings` | conditional modify | 새 사용자 대면 문구가 생긴 경우만 en/ko/ja 등록 |
| `docs/design/phone-design-map/actual/**/images/H02.png`, capture indices, `actual/index.html` | modify | 영향받는 iPhone/iPad/Duo 접힘·펼침 실제 H02 화면을 새 빌드로 갱신 |

`WellnessScoreDetailViewModel.swift`, `WellnessScore.swift`, `CalculateWellnessScoreUseCase.swift`, `DetailScoreHero.swift`, shared chart/composition/calculation components and H01 `WellnessHeroCard.swift` are **read-only reference files** for the chosen scope. Shared component defects found by focused checks require a separately justified consumer impact assessment.

## Implementation Steps

### Step 1: Fix the visual and evidence contract

- **Files**: H02 layout map and index; `.codex-checks/h02/before-historical` read only.
- **Changes**: map all current sections/branches and dark opaque hero + adaptive widths. Capture the unchanged original H02 with `WellnessRegressionTests/testWellnessRootRendersAndHeroOpensScoreDetail` on the owned device before View edits; retain attachment/seed/appearance/revision provenance. The four historical H02 PNGs are identity-matched but state/theme null and source revision `443a32ca...`, so do not call them state-matched current before images.
- **Verification**: map link, source-to-map inventory, and a baseline receipt/PNG with actual status, period and fixture data noted. If baseline is unavailable, record exact gap; do not reuse historical image as current baseline.

### Step 2: Build H02-only header and one trend card

- **Files**: `WellnessScoreDetailView.swift`; optional H02-only header file.
- **Changes**: preserve the status symbol from `WellnessScore.Status.iconName` and four optional scores from the passed model. Use palette ink/muted on opaque surface, `CompactConditionRing`, actual evaluation date; adapt to one column at accessibility sizes. Set `usesAdaptiveLayout: true` at the TimeOfDay call. Put picker, range/trend header, chart/empty, summary in a single card. Maintain `wellness-chart-trend` and other existing AXIDs, chart height logic and actual scroll/selection.
- **Verification**: code review against all 5 periods and score status boundaries; no VM/service/scoring diff. Compilation comes from focused UI test, not a duplicate build-only command.

### Step 3: Preserve composition and explanation

- **Files**: `WellnessScoreDetailView.swift`, conditional catalog.
- **Changes**: keep `ScoreCompositionCard` 35/30/20/15 and nil indicators; `ScoreContributorsView` only with contributions, `ConditionCalculationCard` only with detail, `BodyCalculationCard` only with body detail, and all `CalculationMethodCard` bullets. If grouping under one `DisclosureGroup`, give clear expand/collapse, 44pt hit area and full VoiceOver/scroll reachability; never remove source details for a cleaner screenshot.
- **Verification**: seeded full/partial state checks and source matrix for conditional RHR card branches; catalog translation/format checks only if strings change.

### Step 4: Focused UI gate and actual design map

- **Files**: H02 UI tests; actual H02 capture indices/images/index.
- **Changes**: use the existing `SeededUITestBaseCase` and Wellness hero route. `--seed-mock` already seeds HealthKit mock data and SwiftData; `WellnessViewModel` computes the **real fixture score** using the use case, which can change with data and posture arrival. Assert against visible/current model semantics or bounded 0–100/status mapping; do **not** hard-code the prototype's 81 or invent a new fixture flag unless an untestable branch truly requires one. Use `--ui-test-no-sleep-trend` for existing empty-sleep branch; `--ui-test-no-body-comparison` tests missing comparison, **not** necessarily missing body score; `--ui-test-wellness-records-only` removes HealthKit data and may leave posture-only score, so inspect expected state before using it as a partial-component fixture.
- **Verification**: `DUNEUITests/WellnessRegressionTests/testWellnessRootRendersAndHeroOpensScoreDetail` proves entry/baseline. New H02 selectors prove status/icon/date, optional component representation, period/trend/range/chart, and any disclosure. Existing opt-in `DuoScoreComponentLayoutTests/testWellnessCompositionScoresFitAtMaximumTextSize` and `testWellnessSubscoreChartsFitAtMaximumTextSize` require `VisualAudit.isEnabled`; a skip is not pass evidence. Capture H02 on regular iPhone, iPad, Duo closed/open only in affected states, with new source/seed/theme/device provenance. No Watch test. `scripts/plan-ui-tests.py --base main` informs scope, then exact `scripts/test-ui.sh --only-testing DUNEUITests/<Class>/<method>` selectors through owned simulator, one runner, targeted 1200s deadline; no requested full suite. If no VM logic changes, skip VM unit suite; if it does, use wellness cases in `DUNETests/ScoreDetailHistoryRegressionTests` and relevant `CalculateWellnessScoreUseCaseTests` only.

## Edge Cases

| Case | Handling |
|------|----------|
| Any of four components nil | Show unavailable mark, preserve 35/30/20/15 reference and use-case reweighting; never synthesize 0 |
| Status crosses 20/40/60/80 boundaries | Derive text, symbol and color from the same current status |
| `.day` versus other periods | Day uses rolling snapshots and no subscore charts; other periods retain approximate trend and three subscore charts |
| Empty chart during/after load | Keep spinner versus real `ScoreDetailEmptyState`; do not show made-up data |
| Condition detail/RHR variants or body detail missing | Preserve optional cards and their original today/latest/baseline/none branches |
| Maximum AX / Duo widths | External number, one-column evidence, chart/card height verified in native viewport |

## Testing Strategy

- **Unit tests**: none for View-only changes; use `ScoreDetailHistoryRegressionTests` wellness arguments and `CalculateWellnessScoreUseCaseTests` only if calculation/ViewModel contracts change.
- **Integration tests**: focused baseline route plus new H02 UI class. Existing Duo score composition/subscore layout tests are optional visual audits and require their explicit flag.
- **Manual verification**: actual light/dark and maximum-text H02 score/status/icon contrast, 4 optional component labels, time card, period transitions, chart point selection, trend toggle, complete conditional calculation/explanation, iPhone/iPad/Duo closed/open. Record precisely which state/device was captured.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Opaque surface reduces icon/label contrast | medium | high | Palette ink/muted, keep icon shape, test/measure affected themes incl. H03 purple/brown lesson |
| Hero refactor affects shared score surfaces | low if H02-local | high | No `DetailScoreHero`/palette changes; inspect diff and consumers |
| Fixed chart frame clips Dynamic Type | medium | high | Compare T04 resolved sizing, native max AX and Duo viewport |
| Grouped disclosure hides original calculation details | medium | medium | Optional only; require 44pt target, all content and AX reachability |
| Seeded score changes with data/posture timing | medium | medium | Assert model-derived status semantics, no literal proposal values; record fixture state |
| Historical PNGs misrepresented as current baseline | medium | medium | Fresh original-source baseline and capture provenance |

## Confidence Assessment

- **Overall**: High for H02-local visual composition; Medium for any optional disclosure or new chart navigation.
- **Reasoning**: Current H02 data/branch contract and H01/T04 palette/ring pattern are explicit. Existing seeded UI route supports a native original baseline without changing app data. The main uncertainty is layout/contrast at maximum text and cross-device states, to resolve by targeted native receipts and new H02 selectors.
