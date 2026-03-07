---
topic: Preferred Exercise Ordering
date: 2026-03-07
status: approved
confidence: medium
related_solutions:
  - docs/solutions/general/2026-02-26-quickstart-ia-usage-tracking-consistency.md
  - docs/solutions/general/2026-03-07-exercise-variant-canonical-dedup.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-preferred-exercise-ordering.md
---

# Implementation Plan: Preferred Exercise Ordering

## Context

사용자가 설정에서 선호 운동을 지정하면 iPhone과 Watch의 Quick Start 계열 진입점에서 같은 우선순위로 노출되어야 한다. 현재는 `Popular`/`Recent`만 있고 user-curated priority가 없어서 원하는 운동을 빠르게 찾기 어렵다.

## Requirements

### Functional

- 설정에 `Preferred Exercises` 전용 화면을 추가한다.
- 기존 `Exercise Default` 편집 화면에도 `Preferred Exercise` 토글을 추가한다.
- iPhone Quick Start 허브에서 `Recent → Preferred → Popular` 순서를 적용한다.
- Watch 홈 캐러셀과 전체 운동 화면에도 동일한 우선순위를 적용한다.
- 각 섹션 간 canonical 중복을 제거한다.
- 선호 정보가 WatchConnectivity exercise library sync에 반영된다.

### Non-functional

- 기존 per-exercise defaults 저장 구조와 충돌하지 않아야 한다.
- SwiftData migration이 안전해야 한다.
- 구버전 watch cached payload decode가 깨지지 않아야 한다.
- 기존 quick start canonicalization 규칙을 재사용한다.

## Approach

기존 `ExerciseDefaultRecord`를 선호 운동의 단일 저장소로 확장하고, Watch sync payload에 `isPreferred`를 포함시킨다. iPhone은 기존 Quick Start 허브 로직을 확장하고, Watch는 현재 recent/popular 계산 흐름에 preferred section을 추가해 순서를 재배치한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `ExerciseDefaultRecord`에 `isPreferred` 추가 | 기존 per-exercise 설정/CloudKit 패턴 재사용, edit UI와 연결 쉬움 | migration 필요 | 선택 |
| UserDefaults 기반 별도 preferred store | 구현 단순, Watch sync만 보면 쉬움 | CloudKit parity 깨짐, 설정 모델 이원화 | 미선택 |
| `Exercise Defaults` 화면에만 토글 추가 | 구현 범위 작음 | discoverability 부족 | 미선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/Models/ExerciseDefaultRecord.swift` | modify | `isPreferred` 저장 필드 추가 |
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | modify | 새 schema version + migration stage 추가 |
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | modify | WatchExerciseInfo에 preferred flag 추가, backward-compatible decode 보장 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | modify | preferred snapshot 포함 exercise library sync 추가 |
| `DUNE/App/DUNEApp.swift` | modify | 앱 시작 시 preferred-aware watch sync 경로 사용 |
| `DUNE/Presentation/Settings/SettingsView.swift` | modify | `Preferred Exercises` 진입점 추가 |
| `DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift` | modify | preferred 토글 추가 |
| `DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift` | modify | preferred 표시 보강 |
| `DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift` | add | 전용 preferred selection 화면 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | modify | iPhone Quick Start 섹션/정렬 재구성 |
| `DUNE/Presentation/Exercise/ExerciseView.swift` | modify | preferred IDs 공급 |
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | preferred IDs 공급 |
| `DUNEWatch/Views/CarouselHomeView.swift` | modify | 캐러셀 순서 `Recent → Preferred → Popular` 반영 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | modify | 상단 우선 섹션 추가 |
| `DUNEWatch/Helpers/WatchExerciseHelpers.swift` | modify | preferred-aware 정렬 helper 추가 |
| `DUNETests/*`, `DUNEWatchTests/*` | modify/add | migration/codable/order regression 테스트 |

## Implementation Steps

### Step 1: Persist preferred exercises and sync them to Watch

- **Files**: `ExerciseDefaultRecord.swift`, `AppSchemaVersions.swift`, `WatchConnectivityModels.swift`, `WatchSessionManager.swift`, `DUNEApp.swift`
- **Changes**:
  - `ExerciseDefaultRecord.isPreferred` 추가
  - V11 → V12 lightweight migration 추가
  - `WatchExerciseInfo.isPreferred` 추가 + missing-key decode fallback
  - preferred snapshot을 포함하는 exercise library sync 경로 추가
- **Verification**:
  - project regeneration/build 통과
  - migration container init test 통과
  - watch payload decode regression test 통과

### Step 2: Add settings entry points and editing affordances

- **Files**: `SettingsView.swift`, `ExerciseDefaultEditView.swift`, `ExerciseDefaultsListView.swift`, `PreferredExercisesListView.swift`
- **Changes**:
  - Settings에 전용 `Preferred Exercises` 링크 추가
  - 기존 edit view에 preferred 토글 추가
  - defaults list에 preferred state indicator 추가
  - 전용 preferred selection/search UI 제공
- **Verification**:
  - UI 문자열 localization 누락 없음
  - save/clear 시 preferred-only record가 유지/삭제 조건에 맞게 동작

### Step 3: Apply ordering on iPhone Quick Start

- **Files**: `ExercisePickerView.swift`, `ExerciseView.swift`, `ActivityView.swift`
- **Changes**:
  - preferred IDs 공급
  - Quick Start 허브 섹션을 `Recent → Preferred → Popular`로 재배열
  - 전체 운동 정렬 priority에도 preferred 반영
- **Verification**:
  - recent/preferred/popular canonical 중복이 제거됨
  - 기존 quick start search/browse 흐름 유지

### Step 4: Apply ordering on Watch

- **Files**: `CarouselHomeView.swift`, `QuickStartAllExercisesView.swift`, `WatchExerciseHelpers.swift`
- **Changes**:
  - Watch 캐러셀 섹션 enum에 preferred 추가
  - 캐러셀 순서를 `Routine → Recent → Preferred → Popular → All Exercises`로 변경
  - 전체 운동 화면 상단 섹션과 filtered ordering에 preferred 반영
- **Verification**:
  - Watch route/NavigationStack 규칙 유지
  - section 중복 제거 및 empty fallback 정상 동작

### Step 5: Add regression tests and run project verification

- **Files**: 관련 `DUNETests`, `DUNEWatchTests`
- **Changes**:
  - migration/codable/ordering 회귀 테스트 추가 또는 보강
- **Verification**:
  - `scripts/build-ios.sh`
  - `scripts/test-unit.sh`

## Edge Cases

| Case | Handling |
|------|----------|
| preferred-only record with no defaults | record 유지, clear 조건에서 `isPreferred` 포함 고려 |
| variant ID saved in old record | representative exercise ID로 정규화 후 표시/동기화 |
| old watch cached context without `isPreferred` key | decode 시 `false` default |
| recent/preferred/popular overlap | earlier section wins, later sections에서 canonical 제거 |
| watch library empty | 기존 sync fallback 유지 |

## Testing Strategy

- Unit tests: SwiftData migration container init, WatchExerciseInfo decode fallback, watch preferred ordering helper
- Integration tests: build + iOS/watch unit suites
- Manual verification:
  - Settings에서 preferred 선택/해제
  - iPhone Quick Start 허브 순서 확인
  - Watch 홈 캐러셀과 All Exercises 상단 섹션 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SwiftData migration mismatch | medium | high | 새 schema version 추가 후 container init test 실행 |
| Watch cached payload decode failure | medium | high | custom Codable로 missing key default 처리 |
| iPhone/Watch ordering drift | medium | medium | canonical dedup 규칙 유지, 양쪽 테스트 추가 |
| preferred sync race | low | medium | manager에 cached preferred snapshot 유지 후 context/message sync 재사용 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 quick start/persistence 패턴을 재사용할 수 있지만, SwiftData migration과 WatchConnectivity DTO 변경이 함께 들어가므로 검증이 중요하다.
