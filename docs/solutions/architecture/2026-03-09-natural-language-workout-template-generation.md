---
tags: [foundation-models, workout-template, tool-calling, healthkit-context, exercise-library]
category: architecture
date: 2026-03-09
severity: important
related_files:
  - DUNE/Data/Services/AIWorkoutTemplateGenerator.swift
  - DUNE/Presentation/Exercise/Components/CreateTemplateView.swift
  - DUNE/Presentation/Shared/Extensions/ExerciseRecord+Snapshot.swift
  - DUNETests/AIWorkoutTemplateGeneratorTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-09-foundation-models-integration-pattern.md
---

# Solution: Natural-language workout template generation

## Problem

자연어로 운동 템플릿을 생성하려면 Foundation Models 출력이 실제 운동 라이브러리와 안정적으로 연결되어야 하고, 최근 운동 컨텍스트도 앱 내부 기록만이 아니라 HealthKit 기록까지 반영되어야 한다.

### Symptoms

- "30분 어깨 운동 만들어줘" 같은 요청을 템플릿 생성 화면에서 바로 처리할 수 없었다.
- 생성 결과가 fuzzy search 첫 결과에 의존하면 비슷한 이름의 다른 운동으로 잘못 연결될 수 있었다.
- 템플릿 생성 화면 진입 시 전체 `ExerciseRecord`를 `@Query`로 읽어 오면서 실제로는 상위 일부 기록만 필요한데도 불필요한 fetch가 발생했다.
- HealthKit에만 운동 이력이 있는 사용자에게는 개인화 컨텍스트가 거의 비어 있었다.

### Root Cause

근본 원인은 세 가지였다.

1. 자연어 요청을 `WorkoutTemplate`로 변환하는 전용 Domain/Data 경계가 없었다.
2. exercise name 해석이 "정확히 하나의 후보"를 요구하지 않고 첫 fuzzy match를 그대로 채택했다.
3. 최근 운동 컨텍스트가 SwiftData 수동 기록 중심으로만 구성되어 HealthKit workout summary를 함께 사용하지 않았다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Protocols/NaturalLanguageWorkoutGenerating.swift` | 자연어 템플릿 생성 프로토콜 추가 | Presentation이 Foundation Models 구현 세부사항에 의존하지 않도록 분리 |
| `DUNE/Domain/Models/GeneratedWorkoutTemplate.swift` | 생성 결과 전용 모델 추가 | AI 출력과 저장용 `WorkoutTemplate` 변환 사이의 검증 단계를 분리 |
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | `@Generable` 스키마, tool calling, strict exercise resolution 구현 | on-device 생성 결과를 실제 exercise catalog에 안전하게 매핑 |
| `DUNE/Presentation/Shared/Extensions/ExerciseRecord+Snapshot.swift` | 수동 운동 기록을 AI 컨텍스트 snapshot으로 변환 | prompt 컨텍스트 구성을 재사용 가능하게 유지 |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | 자연어 입력 UI, 생성 액션, manual + HealthKit snapshot 병합 로직 추가 | 템플릿 생성 화면에서 개인화된 자연어 생성 기능 제공 |
| `DUNETests/AIWorkoutTemplateGeneratorTests.swift` | 생성기 helper, invalid slot filtering, ambiguous resolution 테스트 추가 | 모델 출력 검증과 매칭 안전성을 회귀 테스트로 고정 |

### Key Code

```swift
let directMatches = library.search(query: trimmedName).filter { exercise in
    candidateLabels(for: exercise).contains(normalizedName)
}
if directMatches.count == 1, let exact = directMatches.first {
    return exact
}

let fuzzyMatches = library.search(query: trimmedName)
guard fuzzyMatches.count == 1 else {
    return nil
}
return fuzzyMatches.first
```

```swift
let manualSnapshots = (try? modelContext.fetch(descriptor))?
    .map { $0.snapshot(library: library) } ?? []

let healthKitSnapshots = try await workoutService.fetchWorkouts(days: 14)
    .filter { !$0.isFromThisApp && !$0.activityType.primaryMuscles.isEmpty }
    .map { workout in
        ExerciseRecordSnapshot(...)
    }
```

정리하면, AI 출력은 "고유하게 식별 가능한 운동"만 채택하고, 컨텍스트는 최근 수동 기록과 HealthKit workout summary를 합쳐 생성 품질을 높였다.

## Prevention

### Checklist Addition

- [ ] Foundation Models 출력이 catalog entity로 매핑될 때 ambiguous fallback이 없는지 확인한다.
- [ ] 화면에서 최근 기록 일부만 필요하면 `@Query` 전체 로드 대신 `FetchDescriptor` + `fetchLimit`을 우선 검토한다.
- [ ] 운동 추천/생성 컨텍스트는 SwiftData 기록과 HealthKit 요약을 함께 검토해 편향을 줄인다.

### Rule Addition (if applicable)

지금 단계에서 새 rule 파일은 필요하지 않다. 다만 AI 기반 운동 생성 기능을 추가할 때는 exact-or-unique match 원칙을 리뷰 체크리스트로 반복 적용하는 편이 좋다.

## Lessons Learned

- 자연어 생성 기능은 prompt 품질보다 "출력을 안전하게 도메인 모델로 환원하는 규칙"이 더 중요하다.
- 운동 이력 개인화는 앱 내부 기록만 보면 쉽게 빈약해지므로 HealthKit summary를 함께 쓰는 편이 사용자 체감 품질에 직접 연결된다.
- Foundation Models 기능은 생성 자체보다도 fallback, validation, ambiguous match 제거를 먼저 설계해야 ship 가능한 품질이 나온다.
