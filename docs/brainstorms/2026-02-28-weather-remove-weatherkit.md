---
tags: [weather, open-meteo, weatherkit, caching, performance]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: WeatherKit 제거 및 날씨 요청 최적화

## Problem Statement

현재 날씨 시스템이 Apple WeatherKit을 primary로, Open-Meteo를 fallback으로 사용 중.
WeatherKit은 유료 API 한도(월 500,000 호출 무료)가 있고 Apple 종속성이 강함.
또한 대시보드 진입마다 날씨를 요청하여 불필요한 API/위치 호출이 발생.

## Target Users

- 앱 사용자: 대시보드에서 날씨 정보를 확인하는 모든 사용자
- 개발자: WeatherKit 의존성 제거로 유지보수 단순화

## Success Criteria

1. WeatherKit import/dependency가 프로젝트에서 완전히 제거됨
2. Open-Meteo 단독으로 현재와 동일한 기능 제공 (현재 날씨 + 6시간 예보)
3. API 호출 빈도가 75% 감소 (15분 → 1시간 캐시)
4. 위치 요청도 날씨 캐시와 동일 주기로 제한
5. CoachingEngine, WaveBackground 등 기존 소비자에 영향 없음

## Proposed Approach

### 1. WeatherKit 제거

**삭제 대상:**
- `DUNE/Data/Weather/WeatherDataService.swift` — 전체 파일 삭제
- WeatherKit framework 링크 (xcodegen project.yml)
- `WeatherProvider`에서 WeatherKit fallback chain 제거

**유지/승격 대상:**
- `OpenMeteoService` → primary (이미 완전 구현됨)
- `WeatherSnapshot`, `WeatherConditionType`, `WeatherAtmosphere` — 변경 없음
- `LocationService` — 유지 (캐시 주기만 변경)

### 2. 캐시 TTL 1시간으로 변경

**변경 지점:**
- `OpenMeteoService`: 캐시 TTL 15분 → 60분
- `WeatherSnapshot.isStale`: 15분 → 60분
- `LocationService`: 위치 캐시도 60분으로 통일

**효과:**
- 대시보드 진입 시 캐시가 유효하면 API/위치 요청 완전 스킵
- 1시간 내 반복 진입 시 즉시 로딩 (네트워크 0회)

### 3. WeatherProvider 단순화

```
현재: WeatherProvider → WeatherDataService(WeatherKit) → 실패 시 → OpenMeteoService
변경: WeatherProvider → OpenMeteoService (단일 경로)
```

`WeatherProvider`가 불필요해질 수 있음 — OpenMeteoService가 직접 `WeatherProviding` 프로토콜 구현 가능.

### 4. 위치 요청 최적화

- `LocationService.cachedLocation` TTL을 날씨 캐시와 동일하게 60분
- 캐시된 위치가 유효하면 CLLocationManager 호출 없이 즉시 반환
- 위치가 크게 변하지 않는 한 (일상 사용) 1시간 간격이면 충분

## Constraints

- **Open-Meteo 제한**: 비상업적 무료, 상업적 사용 시 라이선스 필요 (MVP 단계 무관)
- **Open-Meteo 응답 시간**: WeatherKit보다 약간 느릴 수 있음 (해외 서버)
- **오프라인**: 캐시 만료 후 네트워크 없으면 stale 데이터 표시 (현재와 동일)

## Edge Cases

| 케이스 | 처리 |
|--------|------|
| Open-Meteo 서버 다운 | stale 캐시 표시 + WeatherCardPlaceholder fallback (현재와 동일) |
| 위치 권한 거부 | WeatherCardPlaceholder 표시 (현재와 동일) |
| 1시간 캐시 중 급격한 날씨 변화 | pull-to-refresh로 강제 갱신 허용 (캐시 무시) |
| 앱 재시작 | 메모리 캐시 초기화 → 첫 요청 시 API 호출 |

## Scope

### MVP (Must-have)
- WeatherDataService.swift 삭제
- WeatherKit framework 링크 제거
- OpenMeteoService를 primary로 승격
- 캐시 TTL 60분으로 변경 (날씨 + 위치)
- WeatherProvider 단순화 또는 제거
- 기존 테스트 유지/수정

### Nice-to-have (Future)
- Pull-to-refresh 시 캐시 강제 무효화
- 디스크 캐시 (앱 재시작 후에도 마지막 날씨 유지)
- 위치 기반 캐시 키 (위치가 크게 변하면 즉시 갱신)

## Open Questions

1. `WeatherProvider` 클래스를 유지할까, OpenMeteoService가 직접 `WeatherProviding`을 구현할까?
2. Pull-to-refresh 시 캐시를 무시하고 강제 갱신할까?

## Affected Files (예상)

| 파일 | 변경 |
|------|------|
| `Data/Weather/WeatherDataService.swift` | 삭제 |
| `Data/Weather/OpenMeteoService.swift` | TTL 변경, primary 승격 |
| `Data/Weather/LocationService.swift` | 위치 캐시 TTL 60분 |
| `Domain/Models/WeatherSnapshot.swift` | `isStale` TTL 60분 |
| `Presentation/Dashboard/DashboardViewModel.swift` | WeatherProvider 의존성 변경 |
| `project.yml` | WeatherKit framework 제거 |
| `DUNETests/OpenMeteoServiceTests.swift` | 필요 시 보강 |

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
