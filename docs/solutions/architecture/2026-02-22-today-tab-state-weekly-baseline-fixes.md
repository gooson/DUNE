---
tags: [swiftui, dashboard, viewmodel, weekly-goal, baseline, stale-state]
category: architecture
date: 2026-02-22
severity: important
related_files:
  - Dailve/Presentation/Dashboard/DashboardViewModel.swift
  - Dailve/Presentation/Dashboard/Components/BaselineTrendBadge.swift
  - Dailve/Presentation/Dashboard/Components/ConditionHeroView.swift
  - Dailve/Presentation/Dashboard/DashboardView.swift
  - DailveTests/DashboardViewModelTests.swift
related_solutions:
  - docs/solutions/architecture/2026-02-17-activity-tab-review-patterns.md
  - docs/solutions/general/2026-02-19-review-p1-p2-training-volume-fixes.md
---

# Solution: Today Tab 상태/주간목표/Baseline 안정화

## Problem

Today 탭 리디자인 이후 상태판단/습관동기 핵심 로직에 신뢰성 리스크가 남아 있었습니다.

### Symptoms

- HRV 로드 실패 시 이전 `conditionScore`가 히어로에 남아 stale 상태로 노출될 수 있음
- `Weekly Goal`이 캘린더 주간이 아닌 최근 7일 기준으로 계산되어 목표 진행률이 왜곡됨
- RHR baseline 평균에 현재 비교일 데이터가 섞여 delta가 완화될 수 있음
- baseline 배지에서 0 변화값이 상승 화살표/하락 색상처럼 모순되게 보일 수 있음
- 히어로의 코칭 파라미터 경로가 미사용(dead path) 상태

### Root Cause

- `loadData()` 시작 시 히어로 상태값 초기화 누락
- `activeDaysThisWeek` 계산 기준이 제품 문구와 불일치(rolling 7d vs weekOfYear)
- RHR baseline 시리즈에서 `rhrDate` 제외 규칙 부재
- 배지 표시 로직에 neutral 상태 분기 없음
- 컴포넌트 API 확장 후 호출부 연결 없이 남은 optional 파라미터

## Solution

뷰모델 상태 초기화, 주간 경계 계산 기준, baseline 제외 규칙, 배지 표현 규칙, 히어로 API 정리를 한 번에 반영했습니다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Dailve/Presentation/Dashboard/DashboardViewModel.swift` | `loadData()` 시작 시 `conditionScore/baselineStatus/recentScores` 초기화 | HRV 실패 후 stale 히어로 방지 |
| `Dailve/Presentation/Dashboard/DashboardViewModel.swift` | `activeDaysThisWeek`를 `Calendar.dateInterval(of: .weekOfYear, for:)` 기준으로 계산 | `Weekly Goal` 문구와 실제 계산 기준 정합성 확보 |
| `Dailve/Presentation/Dashboard/DashboardViewModel.swift` | RHR baseline에서 `rhrDate` 동일 일자 데이터 제외 | baseline delta 왜곡 방지 |
| `Dailve/Presentation/Dashboard/Components/BaselineTrendBadge.swift` | `abs(delta) < 0.05`를 neutral로 처리(아이콘 `minus`, 중립 색상) | 0 변화값 시각적 일관성 확보 |
| `Dailve/Presentation/Dashboard/Components/ConditionHeroView.swift` | 미사용 `coachingMessage` 경로 제거 | 데드 API 제거 및 컴포넌트 단순화 |
| `Dailve/Presentation/Dashboard/DashboardView.swift` | `ConditionHeroView` 호출 인자 정리 | 제거된 API와 정합성 유지 |
| `DailveTests/DashboardViewModelTests.swift` | stale 리셋/주간 경계/RHR baseline 제외 테스트 추가 | 회귀 방지 자동화 |

### Key Code

```swift
// DashboardViewModel.loadData()
errorMessage = nil
conditionScore = nil
baselineStatus = nil
recentScores = []

// Exercise weekly goal (calendar week)
if let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today) {
    let thisWeekWorkouts = workouts.filter { currentWeek.contains($0.date) }
    activeDaysThisWeek = Set(thisWeekWorkouts.map { calendar.startOfDay(for: $0.date) }).count
}

// RHR baseline excludes current comparison day
let baselineSeries = sortedCollection
    .filter { !calendar.isDate($0.date, inSameDayAs: rhrDate) }
```

## Prevention

리뷰 체크리스트에 “UI 문구와 시간 집계 단위 정합성”, “비동기 재로딩 시 stale 상태 초기화”, “baseline 비교 시 현재 샘플 제외 여부”를 추가합니다.

### Checklist Addition

- [ ] `loadData`/`refresh` 진입 시 이전 계산 상태가 명시적으로 reset 되는가?
- [ ] `Weekly/Monthly` 문구와 실제 집계 단위(`weekOfYear`/rolling window)가 일치하는가?
- [ ] baseline 평균 계산에서 비교 대상 현재 일자가 제외되는가?
- [ ] delta=0 주변값이 중립 아이콘/색으로 표현되는가?

### Rule Addition (if applicable)

신규 규칙 파일 추가는 필요 없음. 위 항목을 Today 탭 리뷰 체크포인트로 유지.

## Lessons Learned

- 상태판단 UI는 “최신 데이터의 부재” 자체도 상태이므로, 실패 시 이전 성공값 유지보다 명시적 초기화가 안전합니다.
- “주간 목표”처럼 사용자 약속이 포함된 문구는 캘린더 단위 불일치가 곧 신뢰 저하로 이어집니다.
- baseline 비교는 평균 산식보다 샘플 제외 규칙(현재값 포함 여부)이 결과 신뢰도에 더 크게 작용할 수 있습니다.
