---
tags: [weather, localization, ux, layout]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: 날씨 상세 화면 개선 (Best Time 이동 + Feels 번역 수정)

## Problem Statement

1. **Best Time 섹션이 최하단에 위치**: 운동 최적 시간 정보가 7-day forecast 아래에 있어 발견하기 어려움. 사용자에게 가장 유용한 정보이나 스크롤 없이는 보이지 않음.
2. **"Feels" 번역이 적용되지 않음**: WeatherCard의 `"Feels \(Int(snapshot.feelsLike))°"` 코드에서 `Int` interpolation은 xcstrings 키를 `"Feels %lld°"`로 생성하지만, xcstrings에는 `"Feels %@°"` 키로 등록되어 있어 **키 불일치** → 한국어/일본어 번역("체감 %@°")이 전혀 적용되지 않음.

## Target Users

- 앱 사용자 전체 (날씨 기반 운동 계획)
- 특히 한국어/일본어 사용자 (번역 누락 영향)

## Success Criteria

1. Best Time 섹션이 Hero 바로 아래에 표시됨
2. WeatherCard의 "Feels" 텍스트가 ko/ja에서 정상 번역 표시
3. 기존 레이아웃/성능에 영향 없음

## Root Cause Analysis

### Feels 번역 실패

```
코드: Text("Feels \(Int(snapshot.feelsLike))°")
     → Int interpolation → xcstrings 키: "Feels %lld°"
xcstrings 등록: "Feels %@°" (String format specifier)
     → 키 불일치 → fallback to English
```

**해결**: xcstrings 키를 `"Feels %lld°"`로 수정하거나, 코드에서 `String(Int(...))` 로 변환하여 `%@` 매칭.

## Proposed Approach

### Task 1: Best Time 섹션 이동

**현재 위치** (WeatherDetailView body):
```
1. currentWeatherHero
2. outdoorFitnessSection
3. airQualitySection (conditional)
4. conditionDetailsGrid
5. hourlyForecastSection
6. dailyForecastSection
7. bestTimeSection ← 여기
8. stale indicator
```

**변경 후**:
```
1. currentWeatherHero
2. bestTimeSection ← 여기로 이동
3. outdoorFitnessSection
4. airQualitySection (conditional)
5. conditionDetailsGrid
6. hourlyForecastSection
7. dailyForecastSection
8. stale indicator
```

**변경 파일**: `WeatherDetailView.swift` (body 내 섹션 순서만 변경)

### Task 2: Feels 번역 키 수정

**옵션 A (권장)**: xcstrings 키를 `"Feels %lld°"`로 변경
- 코드 변경 없음
- xcstrings에서 기존 `"Feels %@°"` 키 삭제 → `"Feels %lld°"` 키 추가 + ko/ja 번역 이관

**옵션 B**: 코드에서 `String` 변환
- `Text("Feels \(String(Int(snapshot.feelsLike)))°")` → `%@` 매칭
- xcstrings 변경 없음

## Constraints

- xcstrings orphan 방지: 키 변경 시 기존 키 삭제 필수 (Xcode 경고)
- Hero의 `"Feels like \(Int(snapshot.feelsLike))°C"`도 동일 문제 가능성 → 함께 점검
- 성능: bestTimeSection init-time 계산은 이미 구현되어 있어 위치 변경만으로 충분

## Edge Cases

- `bestHourData == nil`: 조건부 렌더링이므로 nil이면 표시 안 됨 (변경 불필요)
- Feels 차이 < 3도: Hero에서 숨겨지지만 WeatherCard에서는 `feelsLikeDiffers` 기준으로 표시

## Scope

### MVP (Must-have)
- Best Time 섹션 Hero 아래 이동
- WeatherCard "Feels" xcstrings 키 불일치 수정
- Hero "Feels like" 키도 동일 점검/수정

### Nice-to-have (Future)
- Best Time 섹션 디자인 강화 (더 눈에 띄는 카드)
- Feels like 차이가 큰 경우 색상 강조

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Dashboard/WeatherDetailView.swift` | body 내 bestTimeSection 위치 이동 |
| `DUNE/Resources/Localizable.xcstrings` | Feels 키 수정 (`%@` → `%lld`) |

## Open Questions

- Hero의 `"Feels like \(Int(snapshot.feelsLike))°C"` 키도 xcstrings에서 `%@` vs `%lld` 확인 필요

## Next Steps

- [ ] /plan 으로 구현 계획 생성
