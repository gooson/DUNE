---
tags: [weather, localization, layout]
date: 2026-03-03
category: plan
status: approved
---

# Plan: 날씨 상세 화면 개선

## Summary

1. Best Time 섹션을 Hero 바로 아래로 이동
2. "Feels" 번역 키 불일치 수정 (xcstrings `%@` → `%lld`)

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Dashboard/WeatherDetailView.swift` | body 내 bestTimeSection 위치 이동 |
| `DUNE/Resources/Localizable.xcstrings` | `"Feels %@°"` → `"Feels %lld°"`, `"Feels like %@°C"` → `"Feels like %lld°C"` 키 수정 |

## Implementation Steps

### Step 1: Best Time 섹션 이동

`WeatherDetailView.swift` body에서 bestTimeSection을 currentWeatherHero 바로 아래로 이동.

**Before**:
```
currentWeatherHero → outdoorFitnessSection → airQualitySection → conditionDetailsGrid → hourlyForecastSection → dailyForecastSection → bestTimeSection
```

**After**:
```
currentWeatherHero → bestTimeSection → outdoorFitnessSection → airQualitySection → conditionDetailsGrid → hourlyForecastSection → dailyForecastSection
```

### Step 2: xcstrings 키 수정

1. `"Feels %@°"` 키를 `"Feels %lld°"`로 변경 (ko/ja 번역 이관)
2. `"Feels like %@°C"` 키를 `"Feels like %lld°C"`로 변경 (ko/ja 번역 이관)

### Step 3: 빌드 검증

`scripts/build-ios.sh`로 빌드 통과 확인.

## Risk Assessment

- **Low**: 레이아웃 순서 변경만, 새 코드 없음
- **Low**: xcstrings 키 수정은 기존 번역 이관, 새 번역 없음
