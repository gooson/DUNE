---
topic: recommended-workout-improvement
date: 2026-03-04
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-19-exponential-decay-fatigue-model.md
  - architecture/2026-03-02-activity-sync-lock-on-ipad.md
  - general/2026-03-04-watch-workout-discovery-search-usability.md
related_brainstorms:
  - 2026-03-04-recommended-workout-improvement.md
---

# Implementation Plan: 추천 운동 개선 (현실성 + Activity 카드 UX)

## Context

추천 운동이 사용자의 실제 운동 환경(헬스장/홈트), 보유 기구, 관심도와 맞지 않아 실행 가능성이 낮다.  
또한 Activity 탭 추천 카드에서 `시작`과 `대안 펼치기` 동작이 분리되지 않아 UX 이해도가 떨어진다.

## Requirements

### Functional

- Gym/Home 컨텍스트를 선택할 수 있어야 한다.
- 컨텍스트별 보유 기구를 저장/편집할 수 있어야 한다.
- 사용자가 `관심 없음`으로 표시한 운동은 추천에서 제외되어야 한다.
- Activity 추천 카드에서 `바로 시작`, `대안 보기`, `관심 없음` 액션을 명확히 제공해야 한다.

### Non-functional

- SwiftData 모델 변경 없이 구현한다.
- 기존 피로도 기반 추천 계산은 유지하고, 후보 선택 단계에 필터를 적용한다.
- 기존 Activity 동기화 안정성 패턴(`.task(id: recordsUpdateKey)` + debounce)을 깨지 않는다.

## Approach

추천 필터를 UserDefaults 기반 설정 저장소로 분리하고, ActivityViewModel에서 추천 생성 시 constraints를 주입한다.  
UI는 SuggestedWorkoutSection/SuggestedExerciseRow를 개편해 동작 의도(시작 vs 대안 vs 제외)를 명확히 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| SwiftData로 선호도 저장 | 기기간 동기화 가능성 | 마이그레이션/스키마 변경 비용 큼 | 기각 |
| ActivityView에서 후처리 필터만 적용 | 구현 단순 | 후보/대안 품질 저하(필터 후 빈 결과) | 기각 |
| 추천 서비스에 constraints 반영 | 후보 선택 단계부터 일관 필터링 | 함수 시그니처 확장 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/WorkoutSuggestion.swift` | Modify | 추천 constraints 모델 추가 |
| `DUNE/Domain/Models/WorkoutRecommendationContext.swift` | Create | Gym/Home 컨텍스트 enum 추가 |
| `DUNE/Domain/UseCases/WorkoutRecommendationService.swift` | Modify | constraints 기반 후보/대안 필터링 |
| `DUNE/Data/Persistence/WorkoutRecommendationSettingsStore.swift` | Create | 컨텍스트/보유기구/관심없음 저장 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | Modify | 설정 로드/저장 + 추천 재계산 연결 |
| `DUNE/Presentation/Activity/ActivityView.swift` | Modify | 추천 섹션에 설정/액션 콜백 연결 |
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | Modify | 컨텍스트/기구 편집 UI 추가 |
| `DUNE/Presentation/Activity/Components/SuggestedExerciseRow.swift` | Modify | 시작/대안/관심없음 액션 분리 |
| `DUNETests/WorkoutRecommendationServiceTests.swift` | Modify | constraints 필터 테스트 추가 |
| `DUNETests/ActivityViewModelTests.swift` | Modify | 관심없음/기구 필터 반영 테스트 추가 |

## Implementation Steps

### Step 1: 추천 constraints 및 저장소 추가

- **Files**: Domain models + Data store
- **Changes**:
  - `WorkoutRecommendationContext` enum 추가
  - `WorkoutRecommendationConstraints` 모델 추가
  - UserDefaults 기반 `WorkoutRecommendationSettingsStore` 추가
- **Verification**: 기본값(Gym, 기본 장비 셋, 관심없음 비어있음) 읽기/쓰기 단위 검증

### Step 2: 추천 서비스에 constraints 반영

- **Files**: `WorkoutRecommendationService.swift`
- **Changes**:
  - `recommend(..., constraints:)` 시그니처 추가
  - 후보, 대안, compound fallback 전 구간에서 constraints 필터 적용
  - 필터 후 후보 부족 시 허용 범위 fallback 보강
- **Verification**: excluded exercise / unavailable equipment 케이스 테스트 통과

### Step 3: ActivityViewModel 연결

- **Files**: `ActivityViewModel.swift`
- **Changes**:
  - 설정 저장소 주입
  - 컨텍스트 변경, 장비 토글, 관심없음 토글 메서드 추가
  - 변경 시 `recomputeFatigueAndSuggestion()` 즉시 재계산
- **Verification**: 설정 변경 직후 suggestion 반영 확인

### Step 4: Activity 추천 카드 UI 개선

- **Files**: `ActivityView.swift`, `SuggestedWorkoutSection.swift`, `SuggestedExerciseRow.swift`
- **Changes**:
  - Gym/Home 선택 + Equipment 편집 진입
  - 행 액션을 명시 버튼으로 분리: Start / Alternatives / Not Interested
  - alternatives 섹션 시각적 분리로 펼침 의미 명확화
- **Verification**: Activity 탭에서 액션별 동작 일치 확인

### Step 5: 테스트/문서 정리

- **Files**: `DUNETests/*`, `docs/solutions/*`
- **Changes**:
  - unit tests 추가/수정
  - 해결책 문서(compound) 작성
- **Verification**: `scripts/test-unit.sh --ios-only --no-regen` 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 컨텍스트의 장비가 0개 선택됨 | 추천 계산 시 bodyweight 포함 최소 안전 fallback 적용 |
| 관심없음 누적으로 후보 부족 | 허용 장비 범위 내 fallback 후보로 보강 |
| alternatives가 모두 필터링됨 | 대안 버튼 숨김으로 UI 혼란 방지 |
| 컨텍스트 전환 중 빠른 연타 | MainActor 상태 갱신 + 단일 재계산 경로 유지 |

## Testing Strategy

- Unit tests: 추천 constraints 필터/ActivityViewModel 반영 테스트
- Integration tests: Activity 탭 수동 점검 (컨텍스트 전환, 기구 편집, 관심없음 토글)
- Manual verification:
  - Gym 모드: 머신 운동 추천 노출
  - Home 모드: 미보유 기구 운동 미노출
  - 관심없음 체크한 운동 재추천 제거
  - Start 버튼/Alternatives 버튼 동작 분리 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 추천 수 감소로 빈 카드 발생 | Medium | Medium | fallback 후보 생성 로직 추가 |
| UserDefaults 상태가 테스트에 영향 | Medium | Medium | 테스트에서 격리 suite store 주입 |
| 문자열 추가로 localization 누락 | Medium | Low | 기존 키 우선 재사용 + 누락 키는 후속 보강 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 구조(ActivityViewModel 중심 파생 상태)와 잘 맞고, SwiftData 마이그레이션 없이 구현 가능하다.
