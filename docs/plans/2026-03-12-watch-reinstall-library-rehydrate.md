---
tags: [watch, watchconnectivity, templates, quick-start, recent-order, reinstall]
date: 2026-03-12
category: plan
status: approved
---

# Watch Reinstall Library Rehydrate

## Overview

Apple Watch 앱을 재설치하면 watch 로컬 `UserDefaults`와 SwiftData가 비워진다.
현재 구현은 iPhone 쪽 persistent source를 항상 다시 읽어 보내지 않고, watch recent ordering도 로컬 tracker에만 의존해서
재설치 직후 템플릿과 recent 운동 순서가 iPhone 상태를 충분히 복구하지 못한다.

## Background

- `WatchSessionManager`는 watch 요청을 받을 때 template를 `cachedWorkoutTemplates`에서만 재전송한다.
- `CarouselHomeView` / `QuickStartAllExercisesView`의 `recent` section은 `RecentExerciseTracker` 로컬 기록만 사용한다.
- iPhone에는 `WorkoutTemplate`와 `ExerciseRecord`가 SwiftData에 남아 있으므로, 재설치 후 watch는 iPhone snapshot으로 재수화되어야 한다.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift` | 신규. iPhone persistent source에서 watch exercise payload를 만드는 순수 빌더 추가 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | model container 등록, watch 요청 시 fresh fetch 기반 re-sync, exercise library payload builder 사용 |
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | watch exercise payload에 recent metadata 필드 추가 |
| `DUNE/App/DUNEApp.swift` | runtime start 시 WatchSessionManager에 model container 등록 |
| `DUNEWatch/Helpers/WatchExerciseHelpers.swift` | synced recent metadata fallback으로 recent ordering 계산 보강 |
| `DUNEWatch/Views/CarouselHomeView.swift` | recent card label/content invalidation에 synced metadata 반영 |
| `DUNETests/DomainModelCoverageTests.swift` | extended `WatchExerciseInfo` Codable 회귀 테스트 |
| `DUNETests/WatchExerciseLibraryPayloadBuilderTests.swift` | 신규. iPhone source → watch payload recent/template metadata regression 고정 |
| `DUNEWatchTests/WatchExerciseHelpersTests.swift` | recent fallback helper 테스트 추가 |
| `DUNEWatchTests/WatchExerciseInfoHashableTests.swift` | 구버전 payload decode 기본값 회귀 테스트 보강 |

## Implementation Steps

### Step 1: iPhone persistent source 기반 exercise payload builder 분리

- **Files**: `DUNE/Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift`, `DUNE/Domain/Models/WatchConnectivityModels.swift`
- **Changes**:
  - `ExerciseRecord` 이력에서 canonical recent usage metadata를 집계한다.
  - `WatchExerciseInfo`에 watch recent fallback용 metadata를 추가한다.
  - 빌더가 `ExerciseDefinition` + iPhone persisted history를 합쳐 watch payload를 만들도록 분리한다.
- **Verification**: builder unit test에서 recent metadata/legacy decode 기본값 확인

### Step 2: Watch request 시 fresh re-sync 보장

- **Files**: `DUNE/Data/WatchConnectivity/WatchSessionManager.swift`, `DUNE/App/DUNEApp.swift`
- **Changes**:
  - `WatchSessionManager`에 runtime `ModelContainer` 등록 경로를 추가한다.
  - activation 및 watch pull-request 처리 시 cache-only 응답 대신 registered container에서 fresh payload를 만든다.
  - container가 없을 때만 기존 cache fallback을 유지한다.
- **Verification**: compile + request handling 코드 경로가 stale cache 없이 builder를 사용

### Step 3: Watch recent section이 synced metadata를 fallback으로 사용

- **Files**: `DUNEWatch/Helpers/WatchExerciseHelpers.swift`, `DUNEWatch/Views/CarouselHomeView.swift`
- **Changes**:
  - local `RecentExerciseTracker` 기록이 없을 때 `WatchExerciseInfo.lastUsedAt` 기준으로 recent ordering/label을 계산한다.
  - 화면 invalidation key에 new payload metadata를 반영한다.
- **Verification**: watch helper test에서 local history 없이 synced metadata만으로 recent ordering 복구 확인

## Edge Cases

| Case | Handling |
|------|----------|
| iPhone 앱이 아직 foreground launch 되지 않아 cache가 비어 있음 | registered `ModelContainer`에서 fresh fetch 후 payload 생성 |
| 구버전 watch payload decode | 새 필드는 optional/default value로 backward compatible 유지 |
| local watch recent history와 synced history가 모두 존재 | local tracker를 우선하고 synced metadata는 fallback으로만 사용 |
| custom/variant exercise IDs | canonical aggregation으로 recent ordering이 variant별로 분열되지 않게 처리 |

## Testing Strategy

- Unit tests: watch payload builder recent aggregation, `WatchExerciseInfo` Codable backward compatibility
- Watch unit tests: `recentWatchExercises`가 synced `lastUsedAt` fallback을 사용하는지 확인
- Build verification: `scripts/build-ios.sh`
- Targeted tests: `scripts/test-unit.sh --watch-only`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| canonical aggregation과 representative ID 매핑이 달라 정렬이 어긋남 | medium | medium | iPhone builder와 watch helper 모두 canonical ID 기준으로 맞춘다 |
| request 시 background context fetch가 main-actor state와 경쟁 | low | medium | payload builder를 순수 함수로 분리하고 manager에서는 snapshot만 반영한다 |
| payload 필드 추가로 구버전과 호환 문제가 생김 | low | medium | optional/default decode와 round-trip test를 추가한다 |

## Confidence

- **Overall**: Medium
- **Reasoning**: template cache-only 응답과 watch-local recent dependency라는 원인이 명확하고, 수정 범위도 WatchConnectivity payload/rehydrate 경로로 한정된다. 다만 실제 paired-device 재설치 시나리오는 로컬에서 완전 재현이 까다로워 targeted unit coverage가 중요하다.
