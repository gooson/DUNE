---
topic: mac SwiftData migration and refresh stability
date: 2026-03-12
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-01-swiftdata-schema-model-mismatch.md
  - docs/solutions/architecture/2026-03-07-non-distance-cardio-machine-level-model.md
  - docs/solutions/architecture/2026-03-12-mac-cloudkit-remote-change-auto-refresh.md
related_brainstorms:
  - docs/brainstorms/2026-03-03-macos-healthkit-cloud-sync-internalization.md
---

# Implementation Plan: mac SwiftData migration and refresh stability

## Context

macOS에서 CloudKit-backed SwiftData store가 `NSCocoaErrorDomain 134504`와 함께 열리지 않고,
remote change refresh 이후에는 background thread에서 UI state를 갱신하면서 SwiftUI publish 경고가 반복된다.

핵심 원인은 두 갈래다.
1. `ExerciseDefaultRecord.isPreferred` 추가 이후에도 migration plan의 최신 버전이 `AppSchemaV12`로 유지되어,
   배포 당시 V12 checksum과 현재 live model checksum이 어긋났다.
2. `refreshNeededStream` 소비 루프가 main actor 보장 없이 `refreshSignal`을 갱신한다.

## Requirements

### Functional

- 기존 macOS/iPad-on-Mac store가 `unknown model version` 없이 열려야 한다.
- V12 이전/당시 사용자 store가 lightweight migration으로 최신 스키마로 진화해야 한다.
- CloudKit remote change refresh가 반복 경고 없이 UI 갱신을 트리거해야 한다.
- iOS/Vision/watch 공용 migration plan이 깨지지 않아야 한다.

### Non-functional

- 기존 store 삭제 fallback 정책은 유지한다.
- 이전에 배포된 schema checksum을 다시 바꾸지 않는다.
- 회귀를 막는 단위 테스트를 추가한다.

## Approach

배포된 V12를 snapshot schema로 고정하고, 현재 live model을 새 `AppSchemaV13`으로 승격한다.
이렇게 하면 기존 V12 store checksum을 그대로 인식한 뒤 `V12 -> V13` lightweight migration을 수행할 수 있다.

refresh 경고는 `refreshNeededStream` 소비 후 `@State` 갱신을 `MainActor.run`으로 감싸 iOS/Vision 공통으로 정리한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `AppSchemaV12`를 직접 현재 모델로 수정 | 파일 수가 적다 | 이미 배포된 V12 checksum을 다시 바꿔 더 많은 store를 orphan 상태로 만들 수 있다 | 기각 |
| migration 오류 시 store 삭제에 더 적극적으로 의존 | 구현이 단순하다 | 사용자 데이터 손실 위험, 규칙 위반 | 기각 |
| `V12` snapshot 고정 + `V13` 추가 | 배포본 checksum 보존, lightweight migration 가능 | schema 코드와 테스트를 함께 갱신해야 함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | modify | `AppSchemaV12` snapshot 고정, `AppSchemaV13` 추가, migration plan 최신화 |
| `DUNETests/AppMigrationPlanTests.swift` | modify | 최신 schema 버전과 snapshot 회귀 검증 보강 |
| `DUNE/App/ContentView.swift` | modify | refresh stream 소비 후 UI state 갱신을 main actor로 고정 |
| `DUNEVision/App/VisionContentView.swift` | modify | 동일 refresh 경로를 main actor로 고정 |
| `docs/solutions/architecture/...` | add | 해결 내용 문서화 |

## Implementation Steps

### Step 1: Fix migration plan versioning

- **Files**: `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift`
- **Changes**:
  - `AppSchemaV12`를 preferred exercise 추가 직전 snapshot으로 고정
  - `AppSchemaV13`를 현재 live model 기반 schema로 추가
  - `currentSchema`, `schemas`, `stages`를 V13 기준으로 갱신
- **Verification**:
  - schema tests 통과
  - 앱이 기존 store를 unknown version 없이 열 수 있는 구조인지 코드상 확인

### Step 2: Fix refresh state publication threading

- **Files**: `DUNE/App/ContentView.swift`, `DUNEVision/App/VisionContentView.swift`
- **Changes**:
  - `refreshNeededStream` 소비 후 `refreshSignal` 갱신을 `MainActor.run`으로 이동
- **Verification**:
  - 관련 테스트 통과
  - 코드 경로상 background publish warning 유발 지점 제거 확인

### Step 3: Add regression coverage

- **Files**: `DUNETests/AppMigrationPlanTests.swift`
- **Changes**:
  - 최신 schema가 V13인지 검증
  - V12 snapshot과 current schema 사이에 `ExerciseDefaultRecord.isPreferred` 차이가 반영됐는지 검증
- **Verification**:
  - `swift test` 또는 `xcodebuild test` 대상 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| V12 store가 이미 old checksum으로 존재 | V12 snapshot 고정으로 인식 후 V13으로 lightweight migration |
| 새 설치로 store가 비어 있음 | current schema(V13)로 곧바로 생성 |
| remote change가 짧은 간격으로 연속 도착 | 기존 throttle 유지, UI state 갱신만 main actor로 보장 |
| Vision target도 동일 stream을 소비 | 동일 패턴으로 함께 수정 |

## Testing Strategy

- Unit tests: `AppMigrationPlanTests`, `AppRefreshCoordinatorTests` 및 변경 영향 테스트 실행
- Integration tests: `scripts/build-ios.sh`로 전체 빌드 확인
- Manual verification:
  - macOS 앱 실행 시 기존 group container store 로드 확인
  - remote change 후 콘솔에서 background publish 경고 미발생 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| snapshot 모델 정의가 실제 배포본과 다를 수 있음 | medium | high | `0166d12d` 시점 파일 기준으로 V12 snapshot 구성 |
| test runner가 샌드박스/시뮬레이터 제약으로 실패할 수 있음 | medium | medium | 가능한 범위의 unit/build 검증 우선, 제한 시 명시 |
| 추가 schema 버전이 watch/vision target에 영향 | low | medium | 공용 migration plan 테스트와 전체 빌드로 확인 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 원인 모델 변경 커밋과 migration plan 불일치가 저장소 히스토리에서 직접 확인됐고, refresh warning도 공용 소비 루프에서 재현 가능한 구조적 문제다.
