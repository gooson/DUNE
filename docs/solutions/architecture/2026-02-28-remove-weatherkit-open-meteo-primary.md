---
tags: [weather, open-meteo, weatherkit, caching, refactor, dependency-removal]
date: 2026-02-28
category: solution
status: implemented
---

# WeatherKit 제거 및 Open-Meteo 단독 승격

## Problem

- Apple WeatherKit은 유료 API 한도(월 500,000 호출)와 Apple 종속성이 있음
- 15분 캐시 TTL로 대시보드 진입마다 불필요한 API/위치 요청 발생
- Fallback chain (WeatherKit → Open-Meteo)이 단일 소스로 충분한 상황에서 불필요한 복잡성

## Solution

### 1. WeatherKit 완전 제거

- `WeatherDataService.swift` 삭제 (WeatherKit import 유일 파일)
- `project.yml`에서 `WeatherKit.framework` 및 entitlement 제거
- `DUNE.entitlements`에서 `com.apple.developer.weatherkit` 제거
- 프로토콜 (`WeatherFetching`, `WeatherProviding`) + `WeatherProvider`를 새 `WeatherProvider.swift`로 추출

### 2. Open-Meteo 단독 승격

- `WeatherProvider.init`의 default: `WeatherDataService()` → `OpenMeteoService()`
- Fallback chain 제거 (단일 서비스, 오류 시 graceful degradation)
- SettingsView attribution: `"Apple WeatherKit, Open-Meteo.com"` → `"Open-Meteo.com (CC BY 4.0)"`

### 3. 캐시 TTL 60분 통일

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| `WeatherSnapshot.isStale` | 15분 | 60분 |
| `LocationService` 위치 캐시 | 15분 | 60분 |
| API 호출 빈도 | ~96회/일 | ~24회/일 (75% 감소) |

### 4. 리뷰에서 발견된 추가 개선

- **P1**: `uv_index` NaN → `Int()` crash 방지 (`isFinite` guard 추가)
- **P2**: 위치 캐시에 `horizontalAccuracy >= 0` 유효성 검증 추가
- **P3**: 좌표 정밀도 4자리 → 2자리 (~1km, 프라이버시 개선)

## Prevention

1. **외부 API 캐시 TTL 변경 시**: 연관된 모든 캐시 (위치, 데이터, staleness) 동시 변경
2. **Float → Int 변환 시**: 반드시 `isFinite` guard 선행 (CLAUDE.md #input-validation 참조)
3. **위치 캐시 TTL 연장 시**: `horizontalAccuracy` 유효성 검증 추가
4. **외부 서비스 전환 시**: attribution 문자열 + docstring 일괄 검색/수정

## Architecture After

```
WeatherProvider.swift
  ├── WeatherFetching (protocol)
  ├── WeatherProviding (protocol)
  ├── WeatherError (enum)
  └── WeatherProvider (class) → OpenMeteoService (sole implementation)

OpenMeteoService.swift
  └── Open-Meteo REST API (keyless, CC BY 4.0)
```
