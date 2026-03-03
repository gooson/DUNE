---
topic: Watch Workout Discovery Usability
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-02-28-watch-carousel-home-pattern.md
  - docs/solutions/general/2026-03-02-title-policy-watch-localization-fixes.md
  - docs/solutions/general/2026-03-03-watch-reinstall-exercise-sync-feedback.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-apple-watch-workout-discovery.md
---

# Implementation Plan: Watch Workout Discovery Usability

## Context

Apple Watch `All Exercises` 화면에서 운동명을 정확히 모르는 상태(특히 기구 이름만 아는 상황)에서는 원하는 운동을 빠르게 찾기 어렵다. 현재 검색은 `exercise.name` 단순 contains만 사용하고, 카테고리 필터가 없어 탐색 범위를 즉시 좁히기 힘들다.

## Requirements

### Functional

- 사용자가 기구 이름/동의어 기반으로도 운동을 찾을 수 있어야 한다.
- `All Exercises` 화면에서 카테고리 기준으로 결과를 필터링할 수 있어야 한다.
- 검색 결과는 기존 quick-start 네비게이션(`WatchRoute.workoutPreview`)과 동일하게 동작해야 한다.
- iPhone→Watch exercise sync payload는 검색 정확도를 높이는 메타데이터를 포함해야 한다.

### Non-functional

- watch navigation 규칙(`NavigationStack(path:)`, enum route)을 유지한다.
- watchOS/iOS 타깃 간 DTO 호환성을 깨지 않는다(기존 payload 누락 시 decode 가능).
- 검색/필터 로직은 순수 함수로 분리해 `DUNEWatchTests`에서 회귀 테스트 가능해야 한다.

## Approach

검색 정확도 개선과 필터 UX를 분리해 적용한다.
1) iPhone sync payload(`WatchExerciseInfo`)에 alias 배열을 추가해 운동명 혼동을 줄인다.
2) watch helper에 검색 인덱싱/카테고리 필터 순수 함수를 추가한다.
3) `QuickStartAllExercisesView`에 카테고리 필터 UI(툴바 메뉴)를 추가하고, 헬퍼 기반 결과 렌더링으로 교체한다.

watch의 `searchable` 입력은 시스템 Dictation(음성 입력)을 기본 제공하므로, 별도 음성 엔진 추가 없이 검색 매칭 정확도(aliases + equipment 키워드) 향상에 집중한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| watch에서 `exercise.name` 단순 contains 유지 | 변경 최소 | 기구/동의어 검색 실패 지속 | 기각 |
| watch 로컬에 별도 alias DB 유지 | 검색 정밀도 높음 | 데이터 중복/동기화 불일치 위험 | 기각 |
| iPhone payload에 alias 포함 + watch 순수 검색 함수 | 단일 source of truth 유지, 테스트 용이 | DTO 확장 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | modify | `WatchExerciseInfo`에 alias 필드 추가 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | modify | watch sync payload에 alias 전달 |
| `DUNEWatch/Helpers/WatchExerciseHelpers.swift` | modify | 카테고리/검색 인덱싱 헬퍼 추가 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | modify | 카테고리 필터 UI + 헬퍼 기반 검색/그룹핑 적용 |
| `DUNEWatchTests/WatchExerciseHelpersTests.swift` | modify | 검색/필터 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Watch Exercise DTO 및 Sync 확장

- **Files**: `WatchConnectivityModels.swift`, `WatchSessionManager.swift`
- **Changes**:
  - `WatchExerciseInfo`에 optional alias 배열(`aliases`) 추가
  - `syncExerciseLibraryToWatch()`에서 `ExerciseDefinition.aliases`를 payload에 매핑
- **Verification**: iOS/watch 타깃 컴파일 성공 + 기존 DTO 생성 코드 호환 확인

### Step 2: 검색/필터 로직 순수 함수화

- **Files**: `WatchExerciseHelpers.swift`
- **Changes**:
  - inputType 기반 카테고리 enum/label 매핑 도입
  - equipment+alias를 포함하는 검색 토큰 생성 함수 추가
  - category filter + search query를 결합한 결과 계산 함수 추가
- **Verification**: helper 단위 테스트에서 equipment/alias/category 매칭 동작 검증

### Step 3: QuickStartAllExercisesView UX 개선

- **Files**: `QuickStartAllExercisesView.swift`
- **Changes**:
  - 툴바 메뉴 기반 카테고리 필터 상태 추가
  - 기존 단순 검색을 helper 기반 검색으로 교체
  - 필터 적용 시 단일 섹션 리스트, 미적용 시 기존 카테고리 섹션 유지
  - 접근성 식별자(기존 list/row) 유지
- **Verification**: watch 빌드 + QuickStart 진입/검색/필터 기본 동작 수동 확인

### Step 4: 테스트 및 품질 게이트

- **Files**: `WatchExerciseHelpersTests.swift` + build/test commands
- **Changes**:
  - 검색(운동명/alias/equipment), 카테고리 필터, 결합 조건 테스트 추가
- **Verification**:
  - `DUNEWatchTests` 대상 테스트 통과
  - `DUNEWatch` scheme build 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 기존 watch cached payload에 aliases 키가 없음 | optional decode로 nil 처리 |
| equipment가 nil/빈 문자열 | equipment 토큰 생성 스킵, name/alias로만 검색 |
| 카테고리 필터 + 검색 동시 사용 | AND 조건으로 좁혀 결과 일관성 유지 |
| inputType 신규 값 유입 | `other` 카테고리 fallback으로 안전 처리 |

## Testing Strategy

- Unit tests:
  - `WatchExerciseHelpersTests`에 category mapping, alias/equipment query 매칭, filter 결합 케이스 추가
- Integration tests:
  - `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEWatch -destination 'generic/platform=watchOS Simulator'`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2' -only-testing:DUNEWatchTests -quiet`
- Manual verification:
  - Quick Start > All Exercises에서 카테고리 변경 시 목록 즉시 반영
  - 검색창에 기구명(예: barbell) 입력 시 관련 운동 노출 확인
  - 검색어 + 카테고리 조합 시 결과가 의도대로 좁혀지는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| DTO 확장으로 인한 타깃 컴파일 회귀 | low | medium | optional 필드 추가 + watch/iOS 동시 빌드 |
| 검색 토큰 과다로 오탐 증가 | medium | low | contains 매칭 대상 최소화(name/alias/equipment/category) |
| watch 리스트 재계산 비용 증가 | low | medium | 기존 `rebuildLists()` 캐시 구조 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 watch quickstart 구조를 유지한 채 DTO 확장 + pure helper + View wiring 조합으로 구현 범위가 명확하고, 회귀 테스트 지점을 직접 확보할 수 있다.
