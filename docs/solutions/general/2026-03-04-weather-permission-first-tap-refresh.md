---
tags: [swiftui, weather, location-permission, dashboard, async, race-condition]
category: general
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNETests/DashboardViewModelTests.swift
related_solutions: []
---

# Solution: Weather 카드 첫 탭 권한 허용 후 즉시 미갱신

## Problem

### Symptoms

- Today 탭에서 날씨 카드가 `Unable to load weather data` 상태로 유지됨
- 사용자가 위치 권한을 허용해도 첫 탭 직후에는 날씨가 갱신되지 않고, 다시 탭해야 표시됨

### Root Cause

`DashboardViewModel.requestLocationPermission()`이 시스템 권한 시트 응답 완료를 기다리지 않고
즉시 `safeWeatherFetch()`를 호출했다.
권한 상태가 아직 `.notDetermined`인 타이밍에 첫 fetch가 실행되어 실패하고, 두 번째 액션에서만 성공했다.

## Solution

권한 요청 후 permission 상태가 확정될 때까지 짧게 대기한 뒤 날씨를 재조회하도록 변경했다.
재조회 결과로 `weatherSnapshot`뿐 아니라 `weatherAtmosphere`와 coaching도 함께 갱신해 UI 상태를 일치시켰다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | `waitForLocationPermissionResolution(using:)` 추가, `requestLocationPermission()`에서 권한 상태 확정 후 날씨 재조회 | 권한 응답 전 fetch 실행 race condition 제거 |
| `DUNETests/DashboardViewModelTests.swift` | Mock `WeatherProviding` 추가 + 권한 지연 확정/즉시 확정 케이스 테스트 추가 | 첫 탭 시나리오 회귀 방지 |

### Key Code

```swift
await weatherProvider.requestLocationPermission()
await waitForLocationPermissionResolution(using: weatherProvider)
let refreshedWeather = await safeWeatherFetch()
weatherSnapshot = refreshedWeather
weatherAtmosphere = refreshedWeather.map { WeatherAtmosphere.from($0) } ?? .default
```

## Prevention

### Checklist

- [ ] 시스템 권한(위치/알림/헬스) 요청 직후 비동기 재조회는 상태 확정 시점과 분리해서 설계한다.
- [ ] 권한 상태 기반 feature는 “첫 액션 성공” 시나리오 테스트를 반드시 추가한다.
- [ ] 날씨처럼 파생 UI 상태(`weatherAtmosphere`, coaching)가 있으면 source state와 함께 갱신한다.

## Verification

- Unit test: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:DUNETests/DashboardViewModelTests -quiet` 통과

