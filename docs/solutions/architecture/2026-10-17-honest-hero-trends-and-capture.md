---
tags: [swiftui, sparse-data, trend-chart, design-map, xctest]
category: architecture
date: 2026-10-17
severity: important
related_files:
  - DUNE/Presentation/Dashboard/Components/ConditionHeroView.swift
  - DUNE/Presentation/Shared/Components/HeroScoreCard.swift
  - DUNE/Domain/UseCases/HabitAnalyticsService.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
  - docs/design/phone-design-map/actual/index.html
related_solutions: []
---

# Solution: 표본이 부족한 히어로 추세와 실제 화면 캡처

## Problem

### Symptoms

- 측정점이 하나인 히어로에서 평평한 선과 같은 최저·현재·최고값이 나타나 안정적인 추세처럼 보였다.
- 측정점이 없는 공유 히어로에서는 그래프 영역이 사라져 화면 구조가 달라졌다.
- Today의 기존 디자인맵 테스트는 Morning Briefing 또는 초기 로딩 오류를 첫 화면으로 캡처했다. 테스트 자체는 통과해도 T03의 현재 구현을 증명하지 못했다.

### Root Cause

차트의 표시 조건이 `points`가 비어 있지 않은지만 검사했다. 다른 경로에서는 빈 데이터를 `nil`로 변환해 안내 분기까지 생략했다. 디자인맵 수집기는 XCTest의 첫 `root after setup` 첨부를 우선하므로, 테스트의 앱 시작 상태가 화면 캡처의 품질을 결정한다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `ConditionHeroView.swift` | 시간별 점이 2개 이상일 때만 차트를 표시하고, 날짜가 다른 일별 점이 2개 이상일 때만 7일 차트를 표시 | 단일 점을 추세로 설명하지 않기 위해 |
| `HeroScoreCard.swift` | 점이 2개 미만이면 제목과 데이터 부족 안내를 같은 그래프 영역에 표시 | Activity와 Wellness 카드의 정보 구조를 유지하기 위해 |
| `HabitAnalyticsService.swift` | 습관 추세 표시 조건을 최근 28일 완료 기록으로 계산 | 표시 기간과 조건의 불일치를 없애기 위해 |
| `DashboardSmokeTests.swift` | Briefing을 끄고 seed된 Today 및 각 탭 첫 화면만 확인하는 캡처 경로 추가 | 실제 히어로를 안정적으로 찍기 위해 |
| `phone-design-map/actual` | T03·A01·H01·L01을 iPhone, iPad, Duo 접힘·펼침에서 새 PNG로 수집 | 현행 화면과 출처를 맞추기 위해 |

### Key Code

```swift
if let sparkline = hourlySparkline, sparkline.points.count >= 2 {
    HourlySparklineView(data: sparkline, ...)
} else {
    Text("Not enough data to show trend.")
}
```

## Prevention

### Checklist Addition

- [ ] 추세 차트에는 서로 구별되는 시점의 점이 두 개 이상 있는가?
- [ ] 표본 0개와 1개가 모두 데이터 부족 상태로 설명되는가?
- [ ] 디자인맵 캡처의 새 PNG가 오버레이·로딩·오류 화면이 아닌 목적 화면인가?
- [ ] Duo 캡처 전후에 활성 LCD 또는 LCD-1을 조회했는가?

### Rule Addition

새 공통 규칙은 추가하지 않는다. 기존 디자인맵 갱신 규칙과 리뷰 체크리스트로 검증한다.

## Lessons Learned

UI 테스트의 성공은 캡처한 이미지의 내용까지 보증하지 않는다. 접근성 계층과 실제 PNG를 함께 확인하고, 빈 데이터의 시각 상태도 컴포넌트 계약으로 다뤄야 한다.
