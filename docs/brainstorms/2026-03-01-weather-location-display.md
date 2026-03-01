---
tags: [weather, location, geocoding, dashboard, UX]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: Weather 표시 영역에 위치(지명) 표시

## Problem Statement

현재 날씨 UI(WeatherCard, WeatherDetailView)에 **어디의 날씨인지** 지명 정보가 없다.
사용자가 이동 중이거나 여러 장소를 오가는 경우, 표시된 날씨가 어디 기준인지 알 수 없다.

## Target Users

- 출퇴근, 출장 등 이동이 잦은 사용자
- "이 날씨 데이터가 내 현재 위치 기준인가?" 확인하고 싶은 사용자

## Success Criteria

1. WeatherCard에 현재 위치 지명(구/동 수준)이 표시된다
2. WeatherDetailView에도 동일한 위치 정보가 표시된다
3. 사용자의 locale에 맞는 언어로 지명이 표시된다 (ko → "서울 강남구", en → "Gangnam-gu, Seoul")
4. 위치 변경 시(이동) 날씨 새로고침과 함께 지명도 업데이트된다

## Proposed Approach

### 구현 방식: CLGeocoder reverse geocoding

**선택 이유**:
- Open-Meteo API는 지명 정보를 반환하지 않음
- `CLGeocoder`는 Apple 기본 API로 추가 의존성 없음
- locale-aware → 자동으로 한국어/일본어/영어 지명 반환
- 한 번 geocoding 후 캐싱하면 네트워크 비용 최소

### 데이터 흐름

```
LocationService (CLLocation)
  → CLGeocoder.reverseGeocodeLocation()
  → CLPlacemark
  → locationName: String (locality + subLocality)
  → WeatherSnapshot에 포함 또는 별도 전달
```

### 표시 포맷

| Locale | CLPlacemark | 표시 |
|--------|------------|------|
| ko | locality="서울특별시", subLocality="강남구" | "서울 강남구" |
| en | locality="Seoul", subLocality="Gangnam-gu" | "Gangnam-gu, Seoul" |
| ja | locality="ソウル特別市", subLocality="江南区" | "ソウル 江南区" |

### 영향 파일

| 파일 | 변경 |
|------|------|
| `WeatherSnapshot.swift` | `locationName: String?` 필드 추가 |
| `LocationService.swift` | reverse geocoding 메서드 추가 |
| `WeatherProvider.swift` | geocoding 결과를 snapshot에 포함 |
| `WeatherCard.swift` | 지명 표시 UI 추가 |
| `WeatherDetailView.swift` | Hero 섹션 또는 navigationTitle에 지명 표시 |
| `Localizable.xcstrings` | 새 문자열 키 추가 (필요시) |

## Constraints

- **네트워크 의존**: CLGeocoder는 네트워크 호출 → 실패 시 graceful fallback 필요
- **Rate limit**: Apple은 CLGeocoder를 과도하게 호출하지 말 것을 권고 → 날씨 fetch 시 1회만 호출
- **캐싱**: 위치가 크게 변하지 않으면(< 1km) 이전 geocoding 결과 재사용
- **Battery**: 기존 LocationService의 `kCLLocationAccuracyKilometer` 유지

## Edge Cases

1. **Geocoding 실패**: 네트워크 없음, 서버 에러 → `locationName = nil` → UI에 지명 생략 (현재와 동일)
2. **Placemark 불완전**: subLocality가 nil인 지역(농촌 등) → locality만 표시
3. **해외 위치**: CLGeocoder가 locale에 맞게 자동 처리
4. **VPN/위치 변조**: CLLocation 기반이므로 영향 없음
5. **첫 실행, 권한 미부여**: 날씨 자체가 안 나오므로 위치도 표시 불필요

## Scope

### MVP (Must-have)
- CLGeocoder reverse geocoding으로 지명 획득
- WeatherSnapshot에 locationName 필드 추가
- WeatherCard에 지명 표시 (온도 옆 또는 condition 아래)
- WeatherDetailView Hero 섹션에 지명 표시
- Geocoding 실패 시 graceful fallback (지명 생략)

### Nice-to-have (Future)
- 수동 위치 설정 (도시 검색)
- 여러 위치 날씨 비교
- 위치 변경 알림

## Open Questions

- WeatherCard에서 지명 위치: 온도 옆? condition 텍스트 대체? 별도 줄? → /plan에서 결정

## Next Steps

- [ ] `/plan weather-location-display` 로 구현 계획 생성
