---
tags: [location, CLLocation, async, sleep-environment, weather, silent-failure]
date: 2026-03-30
category: general
status: implemented
---

# Sleep Environment Data Not Showing — Location Never Requested

## Problem

수면 상세 화면의 "Sleep Environment" 카드가 항상 플레이스홀더를 표시.

**증상**: `SleepEnvironmentCard`에 전달되는 `sleepEnvironment`가 항상 nil.

**근본 원인**: `MetricDetailViewModel.loadSleepEnvironment()`에서 `LocationService`의 `currentLocation` 프로퍼티만 체크했으나, 이 인스턴스에서 `requestLocation()`이 한 번도 호출되지 않아 항상 nil.

```swift
// BUG: currentLocation is always nil on fresh LocationService
guard locationService.isAuthorized,
      let location = locationService.currentLocation else { return }
```

`WeatherProvider.fetchCurrentWeather()`는 `requestLocation()`을 능동적으로 호출하여 정상 동작. 패턴 불일치가 원인.

## Solution

`currentLocation` 수동 체크 → `requestLocation()` 능동 호출로 변경:

```swift
guard await locationService.isAuthorized else { return }
let location = try await locationService.requestLocation()
```

**변경 파일**: `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` (3줄)

**핵심**: `requestLocation()`은 60분 미만 캐시를 즉시 반환하므로 추가 GPS/네트워크 오버헤드 없음. 30초 타임아웃도 내장.

## Prevention

- `LocationService`를 사용할 때는 항상 `requestLocation()`을 호출하여 위치를 능동적으로 가져올 것
- `currentLocation`은 캐시 접근 전용으로만 사용 — 초기값이 nil일 수 있음을 인지
- silent return (`guard ... else { return }`) 패턴은 디버깅이 어려우므로, 최소한 `AppLogger`로 skip 사유를 기록하는 것을 고려

## Lessons Learned

1. **같은 서비스의 다른 소비자 패턴 확인**: `WeatherProvider`는 정상이고 `MetricDetailViewModel`만 비정상. 같은 `LocationService`를 사용하지만 호출 패턴이 달랐음.
2. **Silent guard return은 버그를 숨긴다**: 데이터가 없을 때 플레이스홀더를 보여주는 것은 UX로는 맞지만, 왜 데이터가 없는지 로깅하지 않으면 문제 진단이 어려움.
3. **자체 인스턴스 vs 공유 인스턴스**: `MetricDetailViewModel`이 자체 `LocationService()`를 생성하므로, 대시보드에서 이미 위치를 가져온 것과 무관하게 별도 인스턴스가 초기 상태.
