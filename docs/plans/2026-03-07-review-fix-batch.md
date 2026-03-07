---
topic: review-fix-batch
date: 2026-03-07
status: approved
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-01-swiftdata-schema-model-mismatch.md
  - docs/solutions/general/2026-03-02-run-review-fix-batch.md
  - docs/solutions/architecture/2026-02-28-remove-weatherkit-open-meteo-primary.md
related_brainstorms: []
---

# Implementation Plan: Review Fix Batch

## Context

전수 리뷰에서 4개의 실질 결함이 확인되었다. 저장소 초기화 실패 시 데이터 삭제가 과도하게 수행되고, 날씨/AQI 캐시가 위치를 구분하지 않으며, Open-Meteo 파서가 공유 mutable formatter/decoder에 의존하고, 표준 빌드/테스트 스크립트가 현재 설치된 simulator runtime과 불일치한다.

## Requirements

### Functional

- 저장소 초기화 실패 시 migration/모델 불일치 성격의 오류에만 삭제 복구를 허용한다.
- 날씨/AQI 캐시는 요청 위치를 반영해 잘못된 지역 데이터를 재사용하지 않는다.
- Open-Meteo parsing/decoding 경로는 concurrent refresh에서 공유 mutable parser 상태를 사용하지 않는다.
- 빌드/테스트 스크립트는 설치된 runtime 기준으로 유효한 destination을 선택한다.

### Non-functional

- 기존 SwiftData/CloudKit 복구 패턴과 충돌하지 않아야 한다.
- 변경된 로직은 Swift Testing 기반 회귀 테스트로 고정한다.
- 스크립트는 미래 runtime 변경에도 과도하게 깨지지 않도록 동적 fallback을 제공한다.

## Approach

저장소 복구는 앱별 catch 블록을 단순 삭제 재시도에서 "오류 분류 -> 선택적 삭제 재시도 -> in-memory fallback" 구조로 바꾼다. 날씨/AQI 서비스는 요청 좌표를 Open-Meteo 요청 정밀도(소수 둘째 자리)로 정규화한 cache key를 사용하고, formatter/decoder는 요청 단위 인스턴스로 생성한다. 스크립트는 `simctl ... -j` 출력에서 호환 가능한 최신 runtime/device를 선택하도록 정렬 로직을 도입하고, build는 simulator가 없거나 최소 OS를 만족하지 않으면 `generic/platform=iOS`로 폴백한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 모든 저장소 실패에서 즉시 in-memory fallback만 사용 | 가장 안전, 데이터 삭제 없음 | migration mismatch 같은 복구 가능한 케이스도 영구 비영속 모드로 떨어짐 | 부분 채택 |
| 오류 유형과 무관하게 store 삭제 재시도 유지 | 기존 MVP 동작 유지 | transient 오류에도 사용자 데이터 삭제 | 기각 |
| 날씨 서비스를 actor로 전체 전환 | 동시성 모델이 명확함 | 범위가 커지고 캐시/테스트 수정량 증가 | 기각 |
| simulator OS 기본값만 최신 숫자로 갱신 | 빠름 | 다음 Xcode 업데이트마다 재발 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | update | 저장소 복구 정책 분기 |
| `DUNEWatch/DUNEWatchApp.swift` | update | 저장소 복구 정책 분기 |
| `DUNEVision/App/DUNEVisionApp.swift` | update | 저장소 복구 정책 분기 |
| `DUNE/Data/Weather/OpenMeteoService.swift` | update | 위치별 캐시 + per-request parser |
| `DUNE/Data/Weather/OpenMeteoAirQualityService.swift` | update | 위치별 캐시 + per-request decoder/parser |
| `DUNE/Data/Weather/OpenMeteoRequestLocation.swift` | add | 좌표 정규화/캐시 키 helper |
| `DUNETests/OpenMeteoServiceTests.swift` | update | 위치 캐시/파서 회귀 테스트 |
| `DUNETests/OpenMeteoAirQualityServiceTests.swift` | update | AQ 위치 캐시 회귀 테스트 |
| `DUNETests/PersistentStoreRecoveryTests.swift` | add | 저장소 오류 분류 테스트 |
| `scripts/build-ios.sh` | update | runtime-aware destination 선택 |
| `scripts/test-unit.sh` | update | runtime-aware iOS/watch destination 선택 |
| `.claude/rules/swiftdata-cloudkit.md` | update | 복구 정책 현재 규칙 반영 |

## Implementation Steps

### Step 1: 저장소 복구 정책 정교화

- **Files**: `DUNE/App/DUNEApp.swift`, `DUNEWatch/DUNEWatchApp.swift`, `DUNEVision/App/DUNEVisionApp.swift`
- **Changes**: 오류 분류 helper 추가, migration/모델 버전 불일치 케이스만 삭제 재시도, 나머지는 in-memory fallback
- **Verification**: 오류 분류 유닛 테스트 추가, 앱 코드에서 `deleteStoreFiles` 호출 조건이 명시적으로 제한됨

### Step 2: 날씨/AQI 위치 캐시 및 파서 동시성 수정

- **Files**: `DUNE/Data/Weather/OpenMeteoService.swift`, `DUNE/Data/Weather/OpenMeteoAirQualityService.swift`, `DUNE/Data/Weather/OpenMeteoRequestLocation.swift`
- **Changes**: 위치 정규화 cache key 도입, per-request formatter/decoder 인스턴스 사용
- **Verification**: 다른 좌표 요청이 이전 캐시를 재사용하지 않는 테스트, 기존 parse tests 유지

### Step 3: 빌드/테스트 스크립트 destination 선택 보강

- **Files**: `scripts/build-ios.sh`, `scripts/test-unit.sh`
- **Changes**: exact runtime 부재 시 최신 호환 runtime 선택, build는 generic iOS fallback, watch test도 동일 정책 적용
- **Verification**: local command dry-run과 shell 함수 경로 검토, 현재 설치 runtime(26.3 / 26.2 watch)에 대해 유효 destination 계산

### Step 4: 회귀 검증 및 문서화

- **Files**: `DUNETests/*`, `docs/solutions/*`, `.claude/rules/swiftdata-cloudkit.md`
- **Changes**: 테스트 보강, 해결 문서 작성, 규칙 최신화
- **Verification**: 관련 unit tests/build 실행, review 재점검

## Edge Cases

| Case | Handling |
|------|----------|
| SwiftData 오류가 nested underlying error로 감싸짐 | NSError chain을 순회해 migration signature 탐지 |
| 위치가 자잘하게 흔들리는 경우 | Open-Meteo 요청 정밀도와 같은 소수 둘째 자리로 정규화 |
| simulator runtime이 전혀 없는 CI 환경 | build는 `generic/platform=iOS`, tests는 기존 requested destination 유지 후 명시 실패 |
| watch simulator 이름이 바뀐 경우 | exact name 부재 시 최신 watchOS runtime의 첫 available device 선택 |

## Testing Strategy

- Unit tests: Open-Meteo weather/AQ cache key 회귀, persistent store error classification 회귀
- Integration tests: iOS generic build, iOS/watch targeted unit-test script 실행
- Manual verification: `xcrun simctl list devices available` 결과 기준 destination 선택 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SwiftData migration error 분류가 너무 좁아 복구 가능한 케이스를 놓침 | medium | medium | SwiftData/Core Data migration signature를 code+message 모두 검사 |
| 위치 정규화가 너무 세밀해 cache hit가 줄어듦 | low | low | API 요청 좌표 반올림과 동일한 2-decimal 정책 사용 |
| shell parser 변경이 macOS 기본 bash에서 동작 차이 발생 | low | medium | bash 3 호환 문법 유지, Python helper 중심 구현 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 영향 범위가 명확하고, 각 finding을 직접 겨냥하는 수정 경로와 회귀 테스트를 함께 설계했다.
