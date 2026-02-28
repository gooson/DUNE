---
tags: [weather, open-meteo, weatherkit, refactor]
date: 2026-02-28
category: plan
status: draft
---

# Plan: WeatherKit 제거 및 날씨 요청 최적화

## 목표

1. Apple WeatherKit 의존성 완전 제거
2. Open-Meteo를 단독 날씨 소스로 승격
3. 캐시 TTL 15분 → 60분 (날씨 + 위치)
4. 기존 소비자(WeatherCard, WaveBackground, CoachingEngine) 영향 없음

## Affected Files

| 파일 | 변경 |
|------|------|
| `Data/Weather/WeatherDataService.swift` | 삭제 |
| `Data/Weather/WeatherProvider.swift` | **신규** — 프로토콜 + WeatherProvider 이동 |
| `Data/Weather/OpenMeteoService.swift` | docstring 업데이트 (fallback → primary) |
| `Data/Weather/LocationService.swift` | 캐시 TTL 15분 → 60분 |
| `Domain/Models/WeatherSnapshot.swift` | isStale TTL 15분 → 60분, docstring 수정 |
| `project.yml` | WeatherKit entitlement + framework 제거 |
| `Resources/DUNE.entitlements` | WeatherKit entitlement 제거 |
| `DUNETests/WeatherAtmosphereTests.swift` | staleness 테스트 60분 기준 |

## Implementation Steps

### Step 1: WeatherProvider.swift 생성
- `WeatherFetching`, `WeatherProviding` 프로토콜 이동
- `WeatherError` enum 이동
- `WeatherProvider` 클래스 이동
- default parameter: `WeatherDataService()` → `OpenMeteoService()`
- fallback 제거 (단일 소스)

### Step 2: WeatherDataService.swift 삭제

### Step 3: 캐시 TTL 변경
- `WeatherSnapshot.isStale`: 15*60 → 60*60
- `LocationService.requestLocation()`: 15*60 → 60*60

### Step 4: project.yml + entitlements
- WeatherKit framework 링크 제거
- WeatherKit entitlement 제거

### Step 5: docstring 정리
- OpenMeteoService: "fallback" → "primary"
- WeatherSnapshot: "Created by WeatherDataService" → "Created by OpenMeteoService"

### Step 6: 테스트 수정
- staleness 테스트: 16분 → 61분

### Step 7: xcodegen + 빌드 검증
