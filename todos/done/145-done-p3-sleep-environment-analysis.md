---
source: brainstorm/2026-03-28-sleep-analysis-enhancement
priority: p3
status: done
created: 2026-03-29
updated: 2026-03-29
---

# 수면 환경 분석

## 설명

외부 기온/습도와 수면 품질의 상관관계를 분석하여 시각화한다.

## 상세

- OpenMeteo 날씨 데이터(기온, 습도)와 당일 Sleep Score를 매칭
- 최소 30일 데이터 축적 후 분석 시작
- 산점도 차트: 외부 기온 vs 수면 점수
- 인사이트 카드: "기온 18-22°C에서 수면 품질이 가장 높습니다"
- 기존 `WeatherProvider` + `CalculateSleepScoreUseCase` 활용

## 선행 조건

- 없음 (MVP 완료 후 독립 구현 가능)

## 관련 파일

- `DUNE/Data/Weather/WeatherProvider.swift`
- `DUNE/Domain/UseCases/CalculateSleepScoreUseCase.swift`
- 신규 UseCase + 신규 카드 View
