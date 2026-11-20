---
tags: [training-load, calendar, dst, ui-test, design-map]
category: testing
date: 2026-11-21
severity: important
related_files:
  - DUNE/Presentation/Activity/Components/TrainingLoadWeekTotals.swift
  - DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift
  - DUNETests/TrainingLoadWeekTotalsTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
related_solutions:
  - docs/solutions/testing/2026-03-08-training-load-daily-volume-scroll-history.md
---

# Solution: R07 equal seven-day training load comparison

## Problem

The earlier summary included eight calendar dates in its current period and seven in its previous period, so its percentage compared unequal windows. The wording “This week” also suggested a calendar week although the calculation was rolling.

### Root Cause

The current filter began at today minus seven days and had no exclusive end at tomorrow. The cached summary was tied to point count, so new daily values with the same count could remain stale.

## Solution

Use calendar-day boundaries for today plus six preceding days and the seven dates before that. End at tomorrow 00:00 exclusively. Calendar date arithmetic preserves day buckets through DST. Display the latest period as “Last 7 days” / “최근 7일” / “直近7日間”. Show a 100% decline when current total is zero and previous is positive; omit comparison only when both totals are zero. Recalculate cached chart summaries on same-count value changes while keeping scroll position when the date domain is unchanged.

### Changes Made

| File | Change | Reason |
|---|---|---|
| `TrainingLoadWeekTotals.swift` | Two disjoint seven-day windows | Correct date arithmetic and future exclusion |
| `TrainingLoadChartView.swift` | Correct zero case, label, cache update | Keep visible comparison in sync with values |
| Unit/UI tests | DST, boundary, zero, value update, A06 label | Prevent regression and preserve an actual capture |

## Verification and actual map

- Unit selector: `DUNETests/TrainingLoadWeekTotalsTests`; passed with both March and November DST parameters. The A06 UI assertion verified the displayed label. Same-count view invalidation was checked during source review.
- UI selector: `DUNEUITests/ChartInteractionRegressionUITests/testTrainingLoadChartShowsRollingSevenDaySummaryAndCapturesA06()`. A supplied passed native screenshot is preserved in `docs/design/phone-design-map/actual/r07-training-load-seven-days-2026-11-21/`.
- iPhone evidence: iPhone 18 Pro, iOS 27.2, Korean/light, code `8a0d632d7`. `evidence.json` records the original attachment, SHA-256, and visible scope.
- iPad A06 and Duo folded/open A06 await new captures. Earlier images are historical evidence only.

## Prevention

Define rolling comparisons with explicit inclusive start and exclusive end dates. Include a zero-current/positive-previous case, a DST boundary, and unchanged count with changed values in focused tests. Record device and source revision for each native capture.

## Lessons Learned

Date filters that look one week apart can produce unequal counts when both ends are inclusive. Data count is not a sufficient cache key for a daily chart.

## Native capture verification

- [Actual A06 gallery](../../design/phone-design-map/actual/r07-training-load-seven-days-2026-11-21/index.html) contains 3 native capture(s) linked to passed XCTest cases.
- Source revision `ff202e013a87dc50f47a87927166b79823f3fbe3`; build revision `mixed; inspect devices below`. 기능별 원격 소스와 최종 통합본을 파일 단위로 대조했다. 각 이미지를 통과한 개별 UI 테스트에 연결했다. Duo 내부 화면은 지정된 체크포인트에서 활성 LCD-1 프레임버퍼를 직접 캡처했다. 파일별 빌드·크기·관찰 결과는 아래 기록에 있다.
- Unverified devices: none by device; screen IDs: none by screen ID. Any state absent from evidence.json remains unverified.
- Original file names, dimensions, hashes, test selectors, and timestamps are in gallery evidence.json. Visual inspection: 원본 화면 검토 완료; 7일 막대·기준선과 최근 7일 34.1(+55%) 합계가 같은 카드에 보이고 선택된 기간의 양 끝이 화면에 들어온다. 훈련 부하 카드에는 간격을 둔 11월 16·18·20일 눈금과 최근 7일 34.1(+55%)가 함께 보이며 이웃한 날짜 문자열이 겹치지 않는다. Duo 내부 가로 화면에서 7일 막대와 기준선, 합계와 증감률이 우측 도크와 떨어져 보인다. 활성 내부 패널 원본을 검사했다.; 기능별 캡처 검토.
