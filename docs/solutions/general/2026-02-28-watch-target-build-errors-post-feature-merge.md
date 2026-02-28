---
tags: [xcodegen, watchos, build-error, multi-target, shared-domain, design-system, habit]
category: general
date: 2026-02-28
severity: important
related_files:
  - DUNE/project.yml
  - DUNE/Presentation/Shared/Extensions/WorkoutIntensity+View.swift
  - DUNE/Presentation/Life/HabitRowView.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutView.swift
related_solutions:
  - architecture/2026-02-28-habit-tab-implementation-patterns
  - architecture/2026-02-28-auto-workout-intensity-patterns
---

# Solution: Watch Target Build Errors After Feature Merge

## Problem

Habit Tracking 탭과 Auto Workout Intensity 기능이 머지된 후 프로젝트 빌드 시 3종류의 에러 발생.

### Symptoms

- DUNEWatch 타겟에서 `cannot find type 'HabitType' in scope` 에러 (+ `HabitFrequency`, `HabitIconCategory`)
- `DS.Color.warning` 토큰 미존재 에러
- `WorkoutCompletionSheet` 호출 시 `autoIntensity` 파라미터 누락 에러

### Root Cause

**1. Watch 타겟 Domain 소스 누락**
`project.yml`에서 Watch 타겟이 `Data/Persistence/Models` 폴더 전체를 포함하므로 `HabitDefinition.swift`(@Model)도 컴파일됨. 하지만 이 모델이 의존하는 `Domain/Models/HabitType.swift`는 Shared/Domain 소스 목록에 추가되지 않았음.

**2. DS 색상 토큰 불일치**
`WorkoutIntensity+View.swift`에서 `DS.Color.warning`을 참조했으나 DesignSystem에는 `warning`이 아닌 `caution` 토큰만 존재.

**3. 호출 사이트 미갱신**
`WorkoutCompletionSheet`에 `autoIntensity` 파라미터가 추가되었으나, `CompoundWorkoutView`의 호출 사이트는 갱신되지 않음 (`WorkoutSessionView`만 갱신됨).

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/project.yml` | `Domain/Models/HabitType.swift` Watch Shared/Domain에 추가 | HabitDefinition이 의존하는 Domain 타입 제공 |
| `WorkoutIntensity+View.swift` | `DS.Color.warning` → `DS.Color.caution` | 존재하는 DS 토큰으로 교체 |
| `HabitRowView.swift` | `AnyShapeStyle` type-erasure 적용 | 삼항 연산자에서 Color vs HierarchicalShapeStyle 타입 불일치 해소 |
| `CompoundWorkoutView.swift` | `autoIntensity: nil` 추가 | 누락된 필수 파라미터 보충 |

### Key Code

```swift
// project.yml — Watch Shared/Domain에 HabitType.swift 추가
- path: Domain/Models/HabitType.swift
  group: Shared/Domain

// HabitRowView — .tertiary ShapeStyle 타입 불일치 해소
.foregroundStyle(progress.isCompleted
    ? AnyShapeStyle(DS.Color.positive)
    : AnyShapeStyle(.tertiary))
```

## Prevention

### Checklist Addition

- [ ] 새 @Model 파일을 `Data/Persistence/Models/`에 추가할 때, 해당 모델이 참조하는 Domain 타입이 Watch 타겟 Shared/Domain 목록에 있는지 확인
- [ ] DS 색상 토큰 사용 전 `DesignSystem.swift`에 해당 토큰이 정의되어 있는지 grep으로 사전 확인
- [ ] struct/class의 init 시그니처를 변경할 때 모든 호출 사이트(`grep -rn "StructName("`)를 갱신
- [ ] SwiftUI `.foregroundStyle` 삼항 연산자에서 `Color`와 `HierarchicalShapeStyle`을 혼용할 때 `AnyShapeStyle`로 type-erase

### Rule Addition (if applicable)

기존 Correction #69(Watch DTO 필드 양쪽 동기화)를 확장하여, **새 @Model이 Data/Persistence/Models에 추가될 때 Watch 타겟 소스 동기화**를 체크리스트에 포함하는 것을 권장.

## Lessons Learned

1. **Watch 타겟은 `Data/Persistence/Models` 폴더 전체를 포함한다**: 새 @Model 파일은 자동으로 Watch 빌드에 포함되므로, 해당 모델의 Domain 의존성도 Watch Shared/Domain에 명시적으로 추가해야 함
2. **기능 브랜치 머지 후 전체 빌드 검증 필수**: 개별 기능은 빌드 통과하더라도 머지 후 cross-reference 에러(파라미터 추가, 토큰 불일치)가 발생할 수 있음
3. **DS 토큰 네이밍은 기존 패턴 확인 후 사용**: `warning` vs `caution` 같은 유사 이름이 혼동됨. 새 색상 참조 시 `DesignSystem.swift`에서 정확한 토큰명 확인
