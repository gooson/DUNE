---
topic: macos-healthkit-cloud-mirror-foundation
date: 2026-03-03
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/healthkit/background-notification-system.md
  - docs/solutions/general/2026-02-28-cloudkit-remote-notification-background-mode.md
related_brainstorms:
  - docs/brainstorms/2026-03-03-macos-healthkit-cloud-sync-internalization.md
---

# Implementation Plan: macOS HealthKit Cloud Mirror Foundation

## Context

macOS에서 HealthKit 직접 접근이 불가하므로, iOS/watchOS가 수집한 HealthKit 파생 데이터를 CloudKit으로 내재화한 후 macOS가 이를 읽는 구조가 필요하다.  
현재 코드베이스는 `SharedHealthDataServiceImpl`이 HealthKit 조회 후 메모리 캐시만 유지하고, CloudKit 미러 레이어가 없다.

이번 배치는 "맥 조회 전용 지원"의 선행 단계로, **Health snapshot 미러 모델 + 동기화 파이프라인 기반**을 구현한다.

## Requirements

### Functional

- `SharedHealthSnapshot` 핵심 지표를 SwiftData 모델로 저장할 수 있어야 한다.
- 저장 모델은 CloudKit sync 가능한 스키마여야 한다.
- 기존 ViewModel/화면 로직 변경 없이, snapshot fetch 시 자동 미러링되어야 한다.
- 최신 스냅샷 타임스탬프(`lastSyncedAt`)를 저장해야 한다.

### Non-functional

- CloudKit 호환 제약(relationship optional, additive schema)을 준수해야 한다.
- 기존 HealthKit fetch/refresh 동작을 깨지 않아야 한다.
- 테스트 가능한 순수 변환 로직을 분리해야 한다.

## Approach

`SharedHealthDataService`에 데코레이터를 추가해 fetch 결과를 미러 저장소에 동기화한다.

- 핵심 아이디어: **기존 서비스 계약은 유지하고, 저장 side-effect를 래퍼에서 수행**
- 장점: ViewModel/Presentation 영향 최소화, 기존 회귀 위험 감소
- 저장 데이터는 macOS 소비를 고려해 "today/latest/14-day" 중심으로 정규화

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `AppRefreshCoordinator`에서만 저장 | 구현 지점 단순 | 초기 로딩 경로(`.task`) 누락 가능, 저장 일관성 약함 | 기각 |
| `SharedHealthDataServiceImpl` 내부 직접 저장 | fetch-then-save 일원화 | Data+Persistence 결합 증가, 테스트 복잡도 상승 | 보류 |
| `SharedHealthDataService` 데코레이터(채택) | 기존 코드 침투 최소, 테스트 용이, 점진적 확장 가능 | 서비스 생성부(DUNEApp) 변경 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/Models/HealthSnapshotMirrorRecord.swift` | add | CloudKit 동기화용 미러 모델 추가 |
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | modify | Schema V8 추가 및 migration stage 연결 |
| `DUNE/App/DUNEApp.swift` | modify | 미러링 래퍼 서비스 구성 및 ModelContainer 모델 목록 갱신 |
| `DUNEWatch/DUNEWatchApp.swift` | modify | ModelContainer 모델 목록 갱신(스키마 정합성) |
| `DUNE/Data/Services/HealthSnapshotMirrorMapper.swift` | add | `SharedHealthSnapshot` -> mirror payload 변환 |
| `DUNE/Data/Services/HealthSnapshotMirrorStore.swift` | add | SwiftData upsert 저장소 |
| `DUNE/Data/Services/MirroringSharedHealthDataService.swift` | add | fetch 시 자동 미러 저장 데코레이터 |
| `DUNETests/HealthSnapshotMirrorMapperTests.swift` | add | 변환 규칙 단위 테스트 |
| `DUNETests/MirroringSharedHealthDataServiceTests.swift` | add | 데코레이터 저장 호출 테스트 |
| `docs/solutions/architecture/2026-03-03-macos-healthkit-cloud-mirror-foundation.md` | add | Compound 문서 |

## Implementation Steps

### Step 1: Mirror Model + Schema 추가

- **Files**: `HealthSnapshotMirrorRecord.swift`, `AppSchemaVersions.swift`, `DUNEApp.swift`, `DUNEWatchApp.swift`
- **Changes**:
  - 미러 모델 도입
  - AppSchemaV8 추가 및 V7->V8 migration stage 연결
  - iOS/watch ModelContainer 모델 목록에 신규 모델 반영
- **Verification**:
  - 스키마 컴파일 성공
  - 기존 ModelContainer 초기화 코드 에러 없음

### Step 2: Mapper + Store + Service Decorator 구현

- **Files**: `HealthSnapshotMirrorMapper.swift`, `HealthSnapshotMirrorStore.swift`, `MirroringSharedHealthDataService.swift`, `DUNEApp.swift`
- **Changes**:
  - 스냅샷 정규화 payload 생성
  - `fetchedAt` 기준 upsert 저장
  - 동일 `fetchedAt` 중복 저장 억제
  - `DUNEApp`에서 base shared service를 데코레이터로 감싸서 주입
- **Verification**:
  - fetch 호출 시 mirror store persist 경로 실행
  - 실패 시 원래 snapshot 반환(비차단)

### Step 3: 테스트 + 품질 검증

- **Files**: `HealthSnapshotMirrorMapperTests.swift`, `MirroringSharedHealthDataServiceTests.swift`
- **Changes**:
  - 매퍼 필드 매핑/정렬/결측 처리 테스트
  - 데코레이터의 저장 호출/에러 무시 동작 테스트
- **Verification**:
  - `xcodebuild test` (DUNETests 타깃) 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 스냅샷 일부 source 실패 | `failedSources`를 payload에 저장해 macOS에서 stale/partial 표시 가능 |
| 동일 fetchedAt 재요청 | 데코레이터에서 중복 저장 스킵 |
| mirror 저장 실패 | fetch 성공 흐름은 유지, 로그만 남김 |
| CloudKit 비활성화 모드 | 로컬 저장만 수행 (ModelConfiguration `.none`) |

## Testing Strategy

- Unit tests:
  - Mapper 변환 정확성
  - Decorator persist 호출/오류 격리
- Integration tests:
  - `AppRefreshCoordinatorTests` 회귀
  - `SharedHealthDataServiceTests` 회귀(핵심 서비스 영향 점검)
- Manual verification:
  - 앱 실행 후 fetch 경로에서 mirror 레코드 생성 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| payload 크기 증가로 CloudKit 부하 | Medium | Medium | 초기 스키마는 핵심 지표만 저장, 이후 분할 모델로 확장 |
| migration mismatch | Medium | High | ModelContainer와 VersionedSchema 동시 업데이트 + 2회 실행 검증 |
| 저장 side-effect로 fetch 지연 | Low | Medium | 저장 실패 비차단, mapper/store 경량 유지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 아키텍처 침투가 낮고 테스트 가능성이 높다. 다만 CloudKit payload 크기/실기기 동기화 지연은 추후 실측 보완이 필요하다.
