---
tags: [foundation-models, workout-template, debugging, oslog, privacy, regression-test]
category: general
date: 2026-03-09
severity: important
related_files:
  - DUNE/Data/Services/AIWorkoutTemplateGenerator.swift
  - DUNE/Presentation/Exercise/Components/CreateTemplateView.swift
  - DUNETests/AIWorkoutTemplateGeneratorTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-09-natural-language-workout-template-generation.md
---

# Solution: Natural-language workout template failure debugging

## Problem

실기기에서 자연어 운동 템플릿 생성이 `"We couldn't turn that request into a workout yet."`로 실패했지만, 기존 코드만으로는 실패 지점이 보이지 않았다. Foundation Models 런타임 문제인지, 모델 응답이 잘못된 건지, exercise library 매칭이 모호한 건지 구분할 수 없었다.

### Symptoms

- iPhone/iPad 실기기에서 템플릿 생성 버튼을 눌러도 운동 목록이 비어 있는 채로 실패 메시지만 표시된다.
- 동일 프롬프트를 더 구체적으로 바꿔도 결과가 같아 재현은 되지만 원인이 보이지 않는다.
- `Reporter disconnected` 같은 런타임 로그가 보여도 실제 사용자 오류와 직접 연결되는지 판단할 수 없었다.
- 디버깅을 위해 모델 출력과 slot 정보를 로그에 남기면, health/workout intent가 공개 OSLog로 노출될 위험이 있었다.

### Root Cause

근본 원인은 두 가지였다.

1. `AIWorkoutTemplateGenerator`는 `noExercisesMatched`가 나더라도 어떤 slot이 왜 탈락했는지 기록하지 않아, 실패 원인을 런타임에서 분해할 수 없었다.
2. 초기 디버깅 로그는 모델이 생성한 템플릿 이름, 운동 이름, slot 상세를 그대로 남기기 쉬워서 health-related user intent를 공개 로그에 새길 위험이 있었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | 모델 원응답, exact/fuzzy lookup ambiguity, unresolved/unsupported/duplicate slot drop reason, final no-match 상태를 추적하는 OSLog 추가 | 실기기 재현 시 실패 지점을 한 번에 식별하기 위해 |
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | 모델 출력 문자열, slot 상세, 에러 문자열을 `.private`로 내리고 count/enum 정보만 `.public` 유지 | 디버깅 가치를 유지하면서 health/workout intent 노출을 막기 위해 |
| `DUNETests/AIWorkoutTemplateGeneratorTests.swift` | unsupported flexibility/HIIT input type가 search/resolve 양쪽에서 계속 배제되는 회귀 테스트 추가 | 실제 실기기 디버깅과 별개로, stale review finding이 다시 열리지 않게 고정하기 위해 |

### Key Code

```swift
AppLogger.exercise.debug(
    "AI workout template raw output promptHash=\(trimmedPrompt, privacy: .private(mask: .hash)) name=\(generated.name, privacy: .private) estimated=\(generated.estimatedMinutes, privacy: .public) slotCount=\(generated.exercises.count, privacy: .public) slots=\(debugSlotSummary(generated.exercises), privacy: .private)"
)
```

```swift
guard let exercise = resolveExercise(
    exerciseID: slot.exerciseID,
    exerciseName: slot.exerciseName,
    library: library
) else {
    AppLogger.exercise.debug(
        "AI workout template dropped unresolved slot id=\(slot.exerciseID, privacy: .private) name=\(slot.exerciseName, privacy: .private)"
    )
    continue
}
```

```swift
if directMatches.count > 1 {
    AppLogger.exercise.debug(
        "AI workout template ambiguous exact lookup name=\(trimmedName, privacy: .private) matchCount=\(directMatches.count, privacy: .public) matches=\(directMatches.map(\.id).joined(separator: ", "), privacy: .private)"
    )
}
```

핵심은 "로그를 추가한다"가 아니라, 실패 원인을 `raw output -> resolve lookup -> slot filtering -> final no match` 단계로 분해하고, health-related 문자열은 전부 private로 유지한 점이다.

## Prevention

### Checklist Addition

- [ ] Foundation Models 결과를 디버깅할 때는 raw output, lookup ambiguity, slot drop reason을 같은 변경에서 함께 남긴다.
- [ ] health/workout intent에서 나온 문자열은 OSLog에 기본적으로 `.private`를 사용하고, 공개 정보는 count/enum 정도로 제한한다.
- [ ] stale review finding을 따라 수정할 때도, 현재 HEAD에서 해당 버그가 실제로 열려 있는지 먼저 재확인한다.
- [ ] 자연어 템플릿 생성 회귀는 search 단계와 resolve 단계 둘 다 테스트로 고정한다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다. 대신 `docs/corrections-active.md`에 health-related debug logging privacy 교정을 추가했다.

## Lessons Learned

- 자연어 기능의 실기기 실패는 모델 품질 문제처럼 보여도, 실제로는 "어느 단계에서 drop됐는지 관찰 불가"가 더 큰 문제일 수 있다.
- health domain에서는 디버깅 로그도 product data contract의 일부로 봐야 한다. 공개 로그는 최소 정보만, 나머지는 private로 두는 편이 안전하다.
- 리뷰 finding이 들어와도 먼저 현재 코드 기준으로 stale 여부를 가려야, 실제 버그 수정과 진짜 디버깅 이슈를 섞지 않게 된다.
