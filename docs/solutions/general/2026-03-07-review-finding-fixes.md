---
tags: [swiftdata, cloudkit, migration-recovery, weather-cache, concurrency, xcodebuild, simulator]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNEVision/App/DUNEVisionApp.swift
  - DUNEWatch/DUNEWatchApp.swift
  - DUNE/Data/Persistence/Migration/PersistentStoreRecovery.swift
  - DUNE/Data/Weather/OpenMeteoService.swift
  - DUNE/Data/Weather/OpenMeteoAirQualityService.swift
  - DUNE/Data/Weather/OpenMeteoRequestLocation.swift
  - DUNETests/OpenMeteoServiceTests.swift
  - DUNETests/OpenMeteoAirQualityServiceTests.swift
  - DUNETests/PersistentStoreRecoveryTests.swift
  - DUNETests/Helpers/URLProtocolStub.swift
  - scripts/build-ios.sh
  - scripts/test-unit.sh
related_solutions: []
---

# Solution: Review Finding Batch Fixes

## Problem

리뷰에서 네 가지 문제가 동시에 발견됐다.

### Symptoms

- `ModelContainer` 초기화 실패가 migration 여부와 관계없이 store 삭제로 이어졌다.
- 날씨/AQI 캐시가 요청 위치를 구분하지 않아 이동 중 다른 도시 데이터가 재사용될 수 있었다.
- Open-Meteo 파서가 공유 formatter/decoder 상태를 재사용해 동시 refresh에서 경쟁 상태가 생길 수 있었다.
- 기본 빌드/테스트 스크립트가 현재 설치된 simulator runtime과 맞지 않는 목적지를 기본값으로 사용했다.

### Root Cause

- 영속 저장소 복구 정책이 "초기화 실패 = store 삭제"로 너무 넓게 잡혀 있었다.
- 캐시 키가 `CLLocation`이 아니라 단일 스냅샷 인스턴스만 기준으로 설계돼 있었다.
- `DateFormatter`, `ISO8601DateFormatter`, `JSONDecoder`를 process-wide 정적으로 공유했다.
- 스크립트가 특정 simulator OS 버전에 강하게 결합돼 있었고 fallback도 호환성 기준 없이 동작했다.

## Solution

문제별로 복구 범위를 좁히고, 캐시/파서/스크립트 기본값을 실제 실행 환경에 맞게 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/Migration/PersistentStoreRecovery.swift` | migration 시그니처 기반 store 삭제 판단 헬퍼 추가 | 비마이그레이션 오류에서 사용자 데이터 삭제 방지 |
| `DUNE/App/DUNEApp.swift` | 초기화 실패 시 선택적 복구 경로 사용 | iOS 앱에서 무조건 store 삭제 제거 |
| `DUNEWatch/DUNEWatchApp.swift` | 동일한 선택적 복구 경로 적용 | watch 앱도 동일 위험 제거 |
| `DUNEVision/App/DUNEVisionApp.swift` | 동일한 선택적 복구 경로 적용 | vision 앱도 동일 위험 제거 |
| `DUNE/Data/Weather/OpenMeteoRequestLocation.swift` | 위치 정규화 키와 로컬 date parser 추가 | 위치 기반 캐시 키 분리 + formatter 공유 제거 |
| `DUNE/Data/Weather/OpenMeteoService.swift` | 위치별 캐시 엔트리, 로컬 parser 사용 | 잘못된 날씨 재사용 및 formatter 경쟁 상태 제거 |
| `DUNE/Data/Weather/OpenMeteoAirQualityService.swift` | 위치별 캐시 엔트리, decoder/ parser 인스턴스화 | 잘못된 AQI 재사용 및 decoder 경쟁 상태 제거 |
| `DUNETests/Helpers/URLProtocolStub.swift` | 네트워크 스텁 헬퍼 추가 | 위치 캐시 테스트를 독립적으로 작성하기 위함 |
| `DUNETests/OpenMeteoServiceTests.swift` | 동시 파싱, 위치 스코프 캐시 테스트 추가 | formatter/캐시 회귀 방지 |
| `DUNETests/OpenMeteoAirQualityServiceTests.swift` | 위치 스코프 캐시 테스트 추가 | AQI 캐시 회귀 방지 |
| `DUNETests/PersistentStoreRecoveryTests.swift` | migration/non-migration 복구 판정 테스트 추가 | store 삭제 조건 회귀 방지 |
| `scripts/build-ios.sh` | 기본 목적지를 `generic/platform=iOS`로 변경 | 설치된 simulator runtime과 무관하게 빌드 시작 가능 |
| `scripts/test-unit.sh` | runtime fallback을 호환 major 기준으로 재작성 | 없는 simulator OS를 기본값으로 강제하지 않도록 수정 |

### Key Code

```swift
guard PersistentStoreRecovery.shouldDeleteStore(after: error) else {
    return makeInMemoryFallbackContainer()
}

let requestLocation = OpenMeteoRequestLocation(location: location)
if let cached, cached.location == requestLocation, !cached.snapshot.isStale {
    return cached.snapshot
}

static func parseISO8601(_ string: String) -> Date? {
    OpenMeteoDateParser().parseISO8601(string)
}
```

## Prevention

초기화 복구 정책과 캐시 키 설계는 "편의 fallback"이 아니라 데이터 보존/정확성 관점에서 먼저 검토해야 한다.

### Checklist Addition

- [ ] `ModelContainer` 실패 처리에서 store 삭제가 migration 에러에만 한정되는지 확인
- [ ] 캐시가 요청 파라미터 전체를 키로 반영하는지 확인
- [ ] `@unchecked Sendable` 타입이 공유 mutable formatter/decoder를 정적으로 들고 있지 않은지 확인
- [ ] 빌드 스크립트 기본 destination이 특정 설치 runtime에 과도하게 묶여 있지 않은지 확인

### Rule Addition (if applicable)

`swiftdata-cloudkit.md`에 migration 전용 store 삭제 규칙을 추가했다.

## Lessons Learned

리뷰에서 서로 다른 P2 이슈처럼 보이던 항목도 공통적으로 "fallback 범위가 너무 넓다"는 문제로 묶였다.
복구 로직, 캐시 로직, 빌드 스크립트 모두 기본 경로를 보수적으로 설계해야 실제 사용자 데이터와 개발자 피드백 루프를 함께 지킬 수 있다.
