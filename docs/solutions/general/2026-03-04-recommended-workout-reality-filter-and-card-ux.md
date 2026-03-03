---
tags: [activity, workout-recommendation, personalization, equipment-filter, ux]
date: 2026-03-04
category: solution
status: implemented
---

# 추천 운동 현실성 필터 + Activity 카드 UX 개선

## Problem

추천 운동이 사용자 현실(헬스장/홈트, 보유 기구, 관심 없음)과 맞지 않아 실제 시작 전환이 낮았다.

### Symptoms

- 기구가 없거나 관심 없는 운동이 계속 추천됨
- 추천 카드에서 "바로 시작"과 "펼쳐서 대안 보기"의 의미가 모호함
- 추천 컨텍스트(헬스장/홈트) 반영 경로가 없어 추천 신뢰도가 낮음

### Root Cause

- 추천 엔진이 피로도/회복도 기반 계산만 수행하고 사용자 제약(장비/관심)을 입력으로 받지 못함
- Activity UI에 추천 제약을 조정하는 명시적 컨트롤이 없음
- 추천 카드 액션이 분리되지 않아 사용자가 다음 행동을 즉시 결정하기 어려움

## Solution

추천 제약 모델 + 저장소를 추가하고, 추천 서비스/ActivityViewModel/UI를 한 경로로 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/WorkoutRecommendationContext.swift` | 생성 | `gym/home` 컨텍스트와 추천 제약 모델 정의 |
| `DUNE/Data/Persistence/WorkoutRecommendationSettingsStore.swift` | 생성 | 컨텍스트, 보유 기구, 관심없음 운동을 UserDefaults에 저장 |
| `DUNE/Domain/UseCases/WorkoutRecommendationService.swift` | 수정 | `constraints` 입력으로 후보/대안/대체 운동 전체 필터링 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | 수정 | 컨텍스트/기구/관심없음 변경 API + 추천 재계산 연결 |
| `DUNE/Presentation/Activity/ActivityView.swift` | 수정 | 추천 섹션에 상태/콜백 주입 |
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | 수정 | Gym/Home 선택, 기구 편집 시트, 빈 추천 상태 UI 추가 |
| `DUNE/Presentation/Activity/Components/SuggestedExerciseRow.swift` | 수정 | `Start`, `Alternatives`, `Not Interested` 액션 분리 |
| `DUNETests/WorkoutRecommendationServiceTests.swift` | 수정 | 장비/관심없음 제약 필터 테스트 추가 |
| `DUNETests/ActivityViewModelTests.swift` | 수정 | ViewModel 제약 전파/지속성 테스트 추가 |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | 수정 | 신규 모델/스토어 파일 빌드 타깃 등록 |

### Key Code

```swift
// Domain/UseCases/WorkoutRecommendationService.swift
func recommend(
    from records: [ExerciseRecordSnapshot],
    library: ExerciseLibraryQuerying,
    constraints: WorkoutRecommendationConstraints
) -> WorkoutSuggestion? {
    // 후보/복합운동/fallback 전 구간에서 constraints.allows 로 필터링
}
```

```swift
// Presentation/Activity/Components/SuggestedExerciseRow.swift
// 액션 분리: 실행 / 대안 / 제외
Button("Start Workout") { onStart() }
Button(showAlternatives ? "Hide" : "Alternatives") { onToggleAlternatives() }
Button(isExcluded ? "Undo" : "Not Interested") { onToggleInterest() }
```

## Prevention

### Checklist Addition

- [ ] 추천 로직 변경 시 사용자 제약(장비/관심없음/컨텍스트) 입력이 누락되지 않았는지 확인
- [ ] 신규 추천 관련 파일 추가 시 `project.pbxproj` 소스 타깃 등록 여부 확인
- [ ] 추천 카드 액션은 "시작"과 "설정/대안"을 시각적으로 분리해 제공

### Rule Addition

현재 규칙 추가 없이도 재발 방지는 가능하지만, 추천 로직 변경이 잦다면 `activity-recommendation` 전용 체크리스트 룰 추가를 검토한다.

## Lessons Learned

- 추천 품질 문제는 알고리즘 자체보다 "현실 제약 입력 경로" 부재에서 자주 발생한다.
- 추천 UI는 설명보다 액션 구조를 명확히 분리했을 때 전환이 빠르게 개선된다.
- 신규 Swift 파일 추가 시 로컬 빌드가 통과해도 `pbxproj` 누락이 있으면 팀 환경에서 즉시 깨질 수 있으므로 우선 점검해야 한다.
