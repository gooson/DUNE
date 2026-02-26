---
topic: exercise-type-reorg-quickstart
date: 2026-02-26
status: draft
confidence: medium
related_solutions:
  - general/2026-02-18-watch-weight-prefill-pattern.md
  - architecture/2026-02-18-watch-navigation-state-management.md
  - general/2026-02-18-watch-ios-review-p1-p3-comprehensive-fix.md
related_brainstorms:
  - 2026-02-26-exercise-type-reorg-quickstart
---

# Implementation Plan: 운동 종류 통합 + Quick Start 개선

## Context

확정된 brainstorm 의사결정:
- 통합 범위: **prefix 동일 이름군 모두 통합**
- 최신값 키: **`exerciseDefinitionID` 우선 + canonical fallback**
- Watch IA: **Popular(개인화 10개) + Recent**, 전체는 `+`로 진입
- iPhone IA: Watch와 동일 구조
- 이번 배포는 **2단계 중 1단계(접근성 중심)** 우선
- PR/볼륨 집계는 기존 `exerciseDefinitionID` 기반 유지

현재 상태:
- Watch `QuickStartPickerView`는 `Recent + All` 구조이며 Popular/`+` 확장 구조 없음.
- iPhone `ExercisePickerView`는 전체 리스트 + 필터 구조이며 Quick Start 전용 정보구조가 없음.
- `exercises.json`은 템포/일시정지/지구력 변형이 독립 엔트리로 다수 존재.

## Requirements

### Functional

#### Phase 1 (이번 배포)

- Watch Quick Start 기본 화면에서 `Popular(10, 개인화) + Recent`를 우선 노출한다.
- Watch 전체 운동 목록은 `+` 진입점에서만 노출한다.
- iPhone Quick Start(단일 운동 시작)도 동일 IA를 적용한다.
- 기존 템플릿/컴파운드/템플릿 생성 등 "전체 탐색이 필요한 흐름"은 기존 picker UX를 유지한다.

#### Phase 2 (후속 배포)

- prefix 규칙으로 canonical 운동 키를 계산한다.
- 최신값 기억 정책을 도입한다:
- 1순위 `exerciseDefinitionID`
- 2순위 `canonicalExerciseID`
- Watch/iPhone Quick Start의 기본 무게/횟수에 최신값을 반영한다.
- 조회/추천에는 canonical을 적용하되 PR/볼륨 집계 로직은 기존 유지한다.

### Non-functional

- Watch 내비게이션은 `WatchRoute` enum + `NavigationStack(path:)` 패턴을 유지한다.
- 입력 검증/상한 규칙(weight/reps 범위)은 기존 규칙(`input-validation.md`)을 유지한다.
- Layer 경계(`App -> Presentation -> Domain <- Data`)를 깨지 않는다.
- Quick Start 섹션 계산은 캐시 또는 제한된 데이터셋으로 수행해 스크롤 성능을 유지한다.

## Approach

Phase 분리 전략:
- **Phase 1**: IA/접근성 개선만 적용 (정보구조, 섹션, 진입점).
- **Phase 2**: 데이터 의미 통합(canonical) + 최신값 기억을 추가.

설계 원칙:
- 기존 `ExercisePickerView`를 전면 교체하지 않고 Quick Start 전용 모드/래퍼를 추가해 영향 범위를 통제한다.
- Watch 개인화 Popular는 기존 `RecentExerciseTracker`를 확장해 usage score를 계산한다.
- canonical 통합은 즉시 DB 마이그레이션하지 않고 계산 계층(Resolver + fallback)로 도입한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `exercises.json`에서 변형 엔트리를 물리적으로 삭제/병합 | 데이터 모델 단순 | 기존 ID 참조/히스토리/템플릿 호환성 위험 큼 | 기각 |
| iPhone/Watch picker를 하나의 공통 대형 컴포넌트로 즉시 통합 | 중복 감소 | 배포 리스크 큼, 단계적 검증 어려움 | 기각 |
| Quick Start 전용 IA를 별도 도입 후 단계 확장 | 영향 범위 통제, 롤백 용이 | 단기적으로 파일 수 증가 | 채택 |
| 최신값 기억을 canonical만으로 단일화 | 구현 단순 | 변형별 기록 정밀도 저하 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Views/QuickStartPickerView.swift` | Major | `Popular + Recent + +진입` 구조로 개편 |
| `DUNEWatch/ContentView.swift` | Modify | `WatchRoute` 확장(`quickStartAll` 등) |
| `DUNEWatch/Managers/RecentExerciseTracker.swift` | Major | lastUsed + usage score/빈도 기반 API 확장 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | Modify | Quick Start 사용 기록 업데이트 경로 정비 |
| `DUNEWatch/Views/SessionSummaryView.swift` | Modify | 템플릿 운동 완료도 usage 기록 반영(개인화 seed) |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | Major | Quick Start 모드(또는 래퍼) 추가, Popular/Recent/All 분리 |
| `DUNE/Presentation/Exercise/ExerciseView.swift` | Modify | Quick Start picker 모드 적용 + 개인화 입력 데이터 전달 |
| `DUNE/Presentation/Activity/ActivityView.swift` | Modify | Quick Start picker 모드 적용 + 개인화 입력 데이터 전달 |
| `DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift` | Modify | 기존 Full picker 모드 명시(회귀 방지) |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | Modify | 기존 Full picker 모드 명시(회귀 방지) |
| `DUNE/Domain/* (신규 Resolver/Service)` | New | Phase 2 canonical 계산 + 최신값 fallback 규칙 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | Major | Watch 라이브러리 sync 시 defaultWeight/defaultReps 주입(Phase 2) |
| `DUNEWatch/WatchConnectivityManager.swift` | Modify | DTO 동기화(필드 추가 시 양 타겟 동시 반영) |
| `DUNETests/*QuickStart*Tests.swift` | New | 인기 정렬/통합/fallback 규칙 테스트 |
| `DUNETests/*ExercisePicker*Tests.swift` | New/Modify | 섹션 구성/우선순위/경계값 테스트 |

## Implementation Steps

### Step 1: Phase 1 정보구조 모델 정의

- **Files**: `DUNEWatch/Managers/RecentExerciseTracker.swift`, `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` (or 신규 QuickStart 전용 뷰)
- **Changes**:
  - Quick Start용 섹션 모델(`Popular`, `Recent`, `All`)과 중복 제거 우선순위 정의
  - Popular 계산 규칙 정의: 개인화 score 기준 상위 10개
  - iPhone/Watch 모두 같은 섹션 우선순위 계약 문서화
- **Verification**:
  - 샘플 데이터로 섹션 출력 결과가 결정사항과 일치하는지 단위 테스트

### Step 2: Watch Phase 1 구현 (Popular + Recent + +)

- **Files**: `DUNEWatch/Views/QuickStartPickerView.swift`, `DUNEWatch/ContentView.swift`, `DUNEWatch/Managers/RecentExerciseTracker.swift`
- **Changes**:
  - Quick Start 기본 화면에 `Popular`/`Recent`만 노출
  - `+` 액션으로 전체 목록 화면(또는 route) 진입
  - `RecentExerciseTracker`를 usage 누적 가능 구조로 확장하고 stale ID 정리 유지
  - Navigation은 기존 `WatchRoute` 타입 안전 패턴 유지
- **Verification**:
  - Watch 시뮬레이터에서 Quick Start 진입 → Popular/Recent 노출 → `+`로 All 진입
  - 운동 시작/종료 후 Popular 순위가 업데이트되는지 확인

### Step 3: iPhone Phase 1 구현 (동일 IA)

- **Files**: `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift`, `DUNE/Presentation/Exercise/ExerciseView.swift`, `DUNE/Presentation/Activity/ActivityView.swift`
- **Changes**:
  - Quick Start 호출부(`ExerciseView`, `ActivityView`)에 Quick Start 모드 적용
  - 기본 화면은 `Popular + Recent`, 전체는 `+`로 확장
  - 템플릿/컴파운드/생성 플로우는 기존 Full 모드 유지
- **Verification**:
  - iPhone에서 단일 운동 시작 시 IA가 변경되고, 템플릿/컴파운드 picker는 기존 UX 유지

### Step 4: Phase 1 테스트/회귀 방지

- **Files**: `DUNETests/*`
- **Changes**:
  - Popular 계산/중복 제거/상한(10) 테스트
  - 빈 히스토리/단일 히스토리/삭제된 ID(stale) 케이스 테스트
  - 모드별(QuickStart vs Full) 섹션 노출 테스트
- **Verification**:
  - `xcodebuild test ... -only-testing DUNETests`

### Step 5: Phase 2 canonical Resolver 도입

- **Files**: `DUNE/Domain/*`, `DUNE/Data/ExerciseLibraryService.swift`(필요 시)
- **Changes**:
  - prefix 통합 규칙 기반 canonical key 계산기 추가
  - 오탐 방지를 위한 예외 화이트리스트/블랙리스트 포맷 정의
  - canonical 적용 범위를 Quick Start 조회/추천에 한정
- **Verification**:
  - 변형 ID 세트(tempo/paused/endurance) → 동일 canonical로 수렴하는 테스트
  - 예외 케이스가 의도대로 분리되는 테스트

### Step 6: Phase 2 최신값 기억(정확 ID 우선 + canonical fallback)

- **Files**: `DUNE/Data/WatchConnectivity/WatchSessionManager.swift`, Quick Start 관련 저장/조회 계층(신규), `DUNEWatch/WatchConnectivityManager.swift`
- **Changes**:
  - latest set snapshot 저장소 도입 (`lastWeightKg`, `lastReps`, `updatedAt`)
  - 조회 순서:
    - 1차: exact `exerciseDefinitionID`
    - 2차: `canonicalExerciseID`
  - Watch `exerciseLibrary` sync payload에 계산된 default weight/reps 반영
  - DTO 변경 시 iOS/Watch 양쪽 동시 반영
- **Verification**:
  - exact ID 데이터가 있으면 fallback보다 우선되는지 테스트
  - exact 없고 canonical만 있을 때 fallback 동작 테스트

### Step 7: Phase 2 적용 범위 고정 (조회/추천 only)

- **Files**: 추천/조회 경로(`ActivityViewModel`, `ExerciseViewModel` 인근), PR/볼륨 집계 파일
- **Changes**:
  - 조회/추천 경로에 canonical 인식 추가
  - PR/볼륨 집계는 기존 `exerciseDefinitionID` 기반 유지 (회귀 방지 assert)
- **Verification**:
  - PR/볼륨 결과가 기존과 동일함을 회귀 테스트/샘플 데이터로 검증

## Edge Cases

| Case | Handling |
|------|----------|
| Popular 데이터가 없는 신규 사용자 | Recent 우선/비어있으면 최소 fallback 목록 노출 |
| stale exercise ID가 tracker에 남아있음 | 기존 purge 패턴 유지, 라이브러리 기준 정리 |
| prefix 통합 오탐(서로 다른 운동이 묶임) | 예외 화이트리스트 우선 적용 |
| Watch 동기화 지연으로 default 값이 오래됨 | `updatedAt` 기반 최신값만 채택 |
| custom exercise(`custom-*`) canonical 미정 | exact ID만 사용, canonical fallback 제외 |
| Full picker가 필요한 플로우까지 IA가 바뀌는 회귀 | 모드 분리 + 호출부 명시 테스트 |

## Testing Strategy

- Unit tests:
  - Popular 정렬/상한/중복 제거
  - canonical 변환 규칙
  - latest-value lookup 우선순위(exact > canonical)
- Integration tests:
  - iPhone에서 기록 저장 후 Watch Quick Start default 값 반영
  - Watch workout 완료 후 usage/최신값 갱신
- Manual verification:
  - Watch: Quick Start 기본 화면/`+` 확장/운동 시작 경로
  - iPhone: Exercise/Activity의 Quick Start IA 변경 확인
  - 템플릿/컴파운드 picker 회귀 없음 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `ExercisePickerView` 공용 사용처 회귀 | 중 | 높 | Quick Start 모드 분리, 기존 Full 모드 default 유지 |
| prefix 통합 오탐 | 중 | 중 | 예외 목록 + 단위 테스트 세트 고정 |
| Watch DTO 변경 누락(iOS/Watch 불일치) | 중 | 높 | DTO 동시 수정 체크리스트 + 빌드 검증 |
| Popular 계산 비용 증가 | 낮음 | 중 | 캐시/상한(10)/필요 시점 계산 |
| Phase 1/2 경계 모호로 범위 팽창 | 중 | 중 | PR 단위 목표를 Phase별로 분리 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**:
  - 높음: Watch/iPhone 모두 기존 Quick Start 진입점과 관련 파일이 명확하고, 과거 prefill/navigation 패턴이 이미 정리되어 있음
  - 중간: Phase 2의 prefix canonical 규칙은 예외 케이스 관리 품질에 따라 정확도가 달라짐
  - 중간: iPhone picker가 여러 흐름에서 재사용되므로 모드 분리 설계가 핵심
