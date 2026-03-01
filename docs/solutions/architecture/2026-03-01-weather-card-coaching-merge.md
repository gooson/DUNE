---
tags: [weather, coaching, card-merge, layer-boundary, accessibility]
date: 2026-03-01
category: solution
status: implemented
---

# Weather Card + Coaching Card Merge

## Problem

Today 탭에 WeatherCard와 TodayCoachingCard(weather 카테고리)가 별도로 표시되어 정보가 중복됨.
코칭 메시지에 온도값이 포함되어 WeatherCard 헤더와 이중 표시 문제 발생.

## Solution

### 1. WeatherCard에 코칭 insight 통합

WeatherCard가 optional coaching info를 받아 divider 아래에 아이콘 + 메시지 렌더링.
DashboardView에서 weather 카테고리 insight는 WeatherCard에 머지하고, TodayCoachingCard 표시를 억제.

### 2. Domain 모델 디커플링 (InsightInfo)

WeatherCard가 CoachingInsight(Domain) 직접 참조 → layer boundary 위반.
해결: `WeatherCard.InsightInfo` nested struct로 display-ready 데이터만 전달.

```swift
struct WeatherCard: View {
    struct InsightInfo {
        let title: String
        let message: String
        let iconName: String
    }
    let snapshot: WeatherSnapshot
    var insightInfo: InsightInfo?
}
```

### 3. ViewModel에 머지 로직 집중

View body에서 `.category == .weather` 판정이 2곳에 중복 → ViewModel computed property로 통합.

```swift
// DashboardViewModel
var weatherCardInsight: WeatherCard.InsightInfo? {
    guard let insight = focusInsight, insight.category == .weather,
          weatherSnapshot != nil else { return nil }
    return WeatherCard.InsightInfo(title: insight.title, message: insight.message, iconName: insight.iconName)
}

var standaloneCoachingInsight: CoachingInsight? {
    guard let insight = focusInsight else { return nil }
    return (insight.category == .weather && weatherSnapshot != nil) ? nil : insight
}
```

### 4. 코칭 메시지에서 온도 제거

카드 헤더에 이미 온도 표시 → 코칭 메시지의 온도 접두사 제거.
accessibility label에는 `insight.title`을 포함하여 VoiceOver 사용자에게 컨텍스트 제공.

### 5. Optional 배열 force-unwrap 제거

OpenMeteoService에서 `daily.precipitation_probability_max![i]` → `flatMap` 패턴으로 안전 접근.

```swift
daily.precipitation_probability_max.flatMap { i < $0.count ? $0[i] : nil } ?? 0
```

## Prevention

- View가 Domain 모델을 직접 참조할 때 → nested display struct로 디커플링
- View body에서 비즈니스 판정 조건이 2곳+ 등장 → ViewModel computed property로 통합
- 카드 머지 시 accessibility가 자기완결적인지 확인 (merged view 밖에서도 의미 있는 label)
- Optional 배열 접근은 `flatMap` + bounds check 패턴 사용 (force-unwrap 금지)

## Affected Files

| File | Change |
|------|--------|
| `WeatherCard.swift` | InsightInfo struct, level computed, DRY accessibility |
| `DashboardViewModel.swift` | weatherCardInsight, standaloneCoachingInsight |
| `DashboardView.swift` | ViewModel property 사용으로 단순화 |
| `CoachingEngine.swift` | 온도 접두사 제거 |
| `OpenMeteoService.swift` | flatMap 패턴으로 force-unwrap 제거 |
| `Localizable.xcstrings` | 새 메시지 키 + ko/ja 번역 |
