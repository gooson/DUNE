---
tags: [weather, ux, dashboard, outdoor-exercise, theme, detail-page]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: Today 날씨 영역 UX 개선

## Problem Statement

현재 WeatherCard는 정보 밀도가 높고(온도/체감/습도/UV/6시간 예보 모두 한 카드), 읽기 전용이며, 야외운동 적합도가 UI에 직접 노출되지 않는다. 테마 색상이 일부 하드코딩되어 있고, 상세페이지가 없어 사용자가 더 많은 날씨 정보를 볼 수 없다.

## Target Users

- 매일 운동하는 사용자: "오늘 밖에서 운동해도 될까?" 빠른 판단 필요
- 건강 데이터 추적 사용자: 날씨와 컨디션의 상관관계에 관심

## Success Criteria

1. WeatherCard 탭 → 상세페이지 네비게이션 동작
2. 상세페이지에 24시간 시간별 + 7일 주간 예보 표시
3. 야외운동 적합도 점수(0-100) 계산 및 카드/상세페이지 표시
4. 시간대별 운동 추천("오전 10시가 가장 좋아요") 표시
5. 모든 날씨 수치가 테마 accentColor/secondaryColor 반영
6. 카드 정보 밀도 감소 — 핵심 정보만 표면, 나머지는 상세페이지로

## Proposed Approach

### 1. 날씨 카드 UI 개선 (WeatherCard 리디자인)

**현재:**
```
[icon] 23° (체감 19°)  💧62%  ☀️UV 5
[midnight] [3AM] [6AM] [9AM] [noon] [3PM]
```

**개선안:**
```
[큰 날씨 아이콘]  23°     🏃 야외운동 좋아요
[condition text]  체감 19°
                          [chevron →]
```

- 상단: 큰 아이콘 + 온도 + 야외운동 적합도 뱃지
- condition text: "맑음", "흐림" 등 한줄 설명
- 습도/UV/6시간 예보 → 상세페이지로 이동
- 카드 전체 탭 → 상세페이지 push

### 2. 날씨 상세페이지 (WeatherDetailView)

**구조:**
```
[날씨 상세]
├─ 현재 날씨 히어로 섹션
│  ├─ 큰 아이콘 + 온도 + condition
│  ├─ 체감온도, 습도, UV, 풍속 그리드
│  └─ 야외운동 적합도 점수 (0-100) + 이유
│
├─ 시간별 예보 (24시간)
│  └─ 가로 스크롤 + 온도 라인차트
│
├─ 주간 예보 (7일)
│  └─ 일별 아이콘 + 최고/최저 온도 바
│
└─ 운동 추천 시간대
   └─ "오전 10시가 가장 좋아요" + 시간대별 점수 차트
```

### 3. 야외운동 적합도 시스템

**점수 계산 (0-100):**

| 팩터 | 이상적 범위 | 감점 기준 |
|------|------------|----------|
| 온도 (체감) | 15-25°C | 범위 밖 1°C당 -3점 |
| UV 지수 | 0-5 | 6-7: -5, 8-10: -15, 11+: -25 |
| 습도 | 30-60% | 범위 밖 5%당 -3점 |
| 풍속 | 0-20 km/h | 20-40: -10, 40+: -25 |
| 강수 | 없음 | rain: -30, heavyRain: -50, thunderstorm: -60 |

**표현:**
- 80-100: "야외운동 좋아요" (초록)
- 60-79: "괜찮아요" (노랑)
- 40-59: "주의 필요" (주황)
- 0-39: "실내 추천" (빨강)

**시간대별 추천:**
- 24시간 예보 데이터로 각 시간의 적합도 점수 계산
- 가장 높은 점수 시간대를 "베스트 타임"으로 추천

### 4. 테마 색상 통합

**현재 문제:**
- 일부 수치 색상이 하드코딩 (UV badge 등)
- 온도 숫자가 테마 무관하게 동일 색상

**개선:**
- 온도: `theme.primaryTextColor` (큰 숫자)
- 습도/UV/풍속 라벨: `theme.secondaryTextColor`
- 적합도 뱃지: `theme.accentColor` 기반 그라데이션
- condition text: `theme.tertiaryTextColor`
- 차트 색상: `theme.accentColor` → `theme.secondaryColor` 그라데이션

## Constraints

### 기술적
- Open-Meteo API가 24시간 시간별 + 7일 주간 예보 데이터를 지원하는지 확인 필요
  - 현재 6시간만 파싱 중 → 확장 필요
- `WeatherSnapshot` 모델에 hourly 24시간 + daily 7일 데이터 추가 필요
- 적합도 점수 계산은 Domain 레이어 (UseCase 또는 Model computed)

### 아키텍처
- 상세페이지: `WeatherDetailView` + `WeatherDetailViewModel`
- 점수 계산: `OutdoorFitnessScoreUseCase` 또는 `WeatherSnapshot` extension
- 카드 탭 네비게이션: `.navigationDestination(for:)` 패턴 (ContentView 소유)
- 테마 색상: `WeatherConditionType+View.swift` 확장

### 레이어 경계
- Domain: `WeatherSnapshot` 확장 (daily forecast, outdoor score)
- Data: `OpenMeteoService` 확장 (24h hourly + 7day daily 파싱)
- Presentation: `WeatherCard` 리디자인, `WeatherDetailView` 신규

## Edge Cases

- **예보 데이터 부족**: 24시간/7일 미만 데이터 → 있는 만큼만 표시
- **위치 권한 거부**: 기존 placeholder 유지
- **stale 데이터 (>60분)**: stale 표시 + 마지막 업데이트 시각
- **극단 날씨**: 적합도 0점 → "실내 운동을 추천해요" + 경고 색상
- **야간 데이터**: UV 0 고정, 적합도에서 UV 감점 없음
- **API 실패**: 카드 placeholder, 상세페이지 진입 불가

## Scope

### MVP (Must-have)
1. **WeatherCard 리디자인**: 정보 밀도 감소, 적합도 뱃지, 탭 인터랙션
2. **WeatherDetailView**: 24시간 시간별 + 현재 상세 정보
3. **야외운동 적합도 점수**: 0-100 계산 + 카드/상세 표시
4. **테마 색상 통합**: 모든 수치에 테마 색상 반영

### Nice-to-have (Future)
- 7일 주간 예보 (API 확장 필요성 확인 후)
- 시간대별 운동 추천 차트
- 날씨 알림 (극단 날씨 시 푸시)
- 날씨 ↔ 컨디션 상관관계 분석
- 강수 확률 표시
- 바람 방향 표시

## Open Questions

1. **Open-Meteo daily forecast API**: 7일 예보 데이터 형식과 사용 가능 필드 확인 필요
2. **적합도 점수 가중치**: 제안된 감점 기준이 적절한지 실데이터 검증 필요 (Correction #114)
3. **네비게이션 패턴**: WeatherCard 탭 → push vs sheet? (기존 Dashboard 카드들은 어떤 패턴?)
4. **야간 운동 추천**: 야간 시간대도 추천에 포함할 것인지?
5. **카드 높이 변화**: 정보 줄이면 카드가 작아지는데, 다른 카드들과 시각적 균형 이슈

## Next Steps

- [ ] `/plan weather-ux-improvement` 으로 구현 계획 생성
- [ ] Open-Meteo API 24h/7day endpoint 확인
- [ ] 기존 Dashboard 카드 네비게이션 패턴 조사
