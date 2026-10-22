---
tags: [swiftui, hero-card, navigation, first-fold, condition-trend, sleep-summary, accessibility]
category: general
date: 2026-10-22
severity: important
related_files: [DUNE/Presentation/Dashboard/Components/DesertHorizonConditionHeroView.swift, DUNE/Presentation/Activity/ActivityView.swift, DUNE/Presentation/Wellness/Components/WellnessHeroCard.swift]
related_solutions: [docs/solutions/design/hero-cta-button-pattern.md]
---

# Solution: 첫 화면 히어로의 목적지와 데이터 의미 맞추기

## Problem

### Symptoms

- Today 히어로의 본문은 컨디션 상세로 열리는데 별도 버튼은 다른 루트 탭으로 이동했다. 한 카드에 서로 다른 목적지가 섞여 사용자가 탭 결과를 예측하기 어려웠다.
- 시간별 표본이 부족할 때 히어로 추세는 비어 있었고 7일 기록은 별도 카드에만 표시됐다. 7일 차트의 당일 값이 링 점수와 다를 수도 있었다.
- Wellness 수면 막대에 날짜·시간·평균의 의미가 불분명했고, iPad 큰 글씨에서는 가로 요약이 좁아졌다.
- Activity 데이터 조회 중에는 로딩 화면이 준비도·운동 진입을 가렸고, 첫 수정은 로딩 분기에서 운동 기록 전체를 계산했다.

### Root Cause

카드의 CTA를 독립된 시각 요소로만 판단하고, 카드 본문과 목적지의 의미 계약을 먼저 정하지 않았다. 수면·추세 값도 실제 표본의 유효성과 당일 기준을 명시하지 않았으며, 로딩 UI에 기록 기반 추천 계산을 재사용했다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DesertHorizonConditionHeroView.swift`, `DashboardView.swift` | 히어로 안의 다른 탭 전환 버튼을 제거하고 카드 전체를 컨디션 상세 링크로 사용. 시간별→7일→데이터 대기 순으로 추세를 표시하며 당일 차트 값은 현재 링 점수로 맞춤 | 카드 안의 목적지와 표시 데이터가 한 가지 의미를 갖게 함 |
| `WellnessHeroCard.swift`, `WellnessView.swift` | 최근 유효 수면의 날짜·시간과 유효 표본 2개 이상의 7일 평균을 분리. iPad 기본 크기는 2열, 접근성 글씨는 세로 요약. 신체 기록은 수면 예측 뒤로 이동 | 실제 관측값과 예측, 직접 행동의 순서를 분명히 함 |
| `ActivityView.swift` | 조회 중에도 준비도 카드와 운동 검색을 표시. 준비도 값이 없을 때 상세 링크를 비활성화하고 로딩 추천의 기록 조회를 건너뜀 | 데이터 조회 중에도 사용자가 실행 가능한 행동을 유지하며 불필요한 계산을 줄임 |
| `DUNEUITests/Smoke/`, `DUNEUITests/Visual/` | 상세 진입, 7일 fallback, 수면 정확한 값·날짜, iPad 기본·큰 글씨 배치를 실제 seed 데이터로 확인 | UI의 의미와 접근성을 결과로 검증 |

### Key Code

```swift
// 동일한 카드의 추세와 링이 같은 당일 점수를 사용한다.
private var weeklyTrendScores: [ConditionScore] {
    let calendar = Calendar.current
    let history = recentScores.filter { !calendar.isDate($0.date, inSameDayAs: score.date) }
    return Array(([score] + history).prefix(7))
}

// 조회 중에는 기록 전체를 훑지 않고 운동 검색 진입을 제공한다.
suggestedWorkoutSection(useHistory: false)
```

화면별 실제 캡처는 `docs/design/full-redesign-map/review/first-fold-ux-2026-10-22/`에 있다. 펼친 Duo의 어두운 상태는 호스트 정체로 캡처하지 못했으므로 검증 완료 범위에 포함하지 않았다.

## Prevention

### Checklist Addition

- [ ] 히어로의 탭 가능한 면과 보이는 상세 힌트가 같은 목적지를 가리키는가?
- [ ] 차트 당일 값과 같은 카드의 현재 점수가 동일한 데이터 기준을 쓰는가?
- [ ] 관측 수면, 집계 평균, 미래 예측을 날짜와 충분한 표본 기준으로 구분했는가?
- [ ] 로딩 상태의 행동은 값이 없어도 실행 가능한가? 이 분기에서 기록 전체를 계산하지 않는가?
- [ ] iPad와 접근성 글씨에서 줄바꿈·순서·카드 경계를 실제 스크린샷으로 확인했는가?

별도 전역 규칙은 추가하지 않았다. 기존 CTA 패턴은 서로 다른 행동이 필요한 카드에서 계속 유효하며, 이 사례의 목적지 선택 조건을 관련 문서에 보강했다.

## Lessons Learned

히어로의 버튼 배치는 제스처 충돌만 해결해도 충분하지 않다. 카드의 정보와 목적지가 일치해야 하고, 대체 데이터도 같은 현재 시점을 설명해야 한다. 실제 시뮬레이터 seed와 접근성 화면을 확인해야 기간·수면 값·넓은 카드의 배치 문제를 정확히 찾을 수 있다.
