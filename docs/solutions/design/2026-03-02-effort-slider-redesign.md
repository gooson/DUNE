---
tags: [effort, intensity, apple-fitness, slider, rpe, workout-completion]
date: 2026-03-02
category: solution
status: implemented
---

# Apple Fitness 스타일 Effort Slider 재설계

## Problem

기존 RPE 입력 UI(`RPEInputView`)는 이모지 버튼 10개를 가로 스크롤하는 방식으로:
- 사용자가 각 값의 의미를 직관적으로 파악하기 어려움
- 자동 추천 기능 없음 — 매번 수동 입력
- Apple Fitness Effort Rating UX와 불일치

## Solution

### 1. EffortSliderView (새 컴포넌트)

Apple Fitness 스타일 1-10 슬라이더로 교체:
- 큰 숫자 + 카테고리 표시 (Easy/Moderate/Hard/All Out)
- Slider 1-10 (step 1) + sensoryFeedback
- 히스토리 컨텍스트 (Last time, Average)
- 자동 제안값으로 초기화

```swift
struct EffortSliderView: View {
    @Binding var effort: Int?
    let suggestion: EffortSuggestion?
    @State private var sliderValue: Double = 5
    @State private var didInitialize = false
    // .task에서 suggestion으로 초기화 (1회만)
}
```

### 2. EffortCategory (4-level 분류)

```swift
enum EffortCategory: Int, CaseIterable {
    case easy = 1      // 1-3
    case moderate = 2  // 4-6
    case hard = 3      // 7-8
    case allOut = 4    // 9-10
}
```

### 3. suggestEffort() (자동 추천)

`WorkoutIntensityService.suggestEffort(autoIntensityRaw:recentEfforts:)`:
- autoIntensityRaw (0.0-1.0) → effort (1-10) 변환: `Int(round(raw * 9.0)) + 1`
- 히스토리 보정: 최근 3+ 세션의 평균과 편향이 ≥1.0이면 50% 보정
- nil/NaN raw → 최근 effort로 fallback
- 반환: `EffortSuggestion` (suggestedEffort, category, lastEffort, averageEffort)

### 4. 스키마 변경 없음

기존 `ExerciseRecord.rpe: Int?` 필드를 재사용. V7→V8 마이그레이션 불필요.

## Key Decisions

| 결정 | 선택 | 이유 |
|------|------|------|
| 입력 방식 | Slider (버튼 아닌) | Apple Fitness 일관성, 연속적 피드백 |
| 필드 재사용 | `rpe` = effort | 스키마 변경 없이 기존 데이터 활용 |
| 초기화 시점 | `.task` + `didInitialize` | `onAppear` re-fire 방지 |
| 카테고리 수 | 4-level | Apple Fitness 동일 (Easy/Moderate/Hard/All Out) |
| 보정 강도 | bias * 0.5 | 점진적 조정, 급격한 변동 방지 |

## Prevention

- **EffortSliderView 초기화**: `.onAppear` 대신 `.task` + guard 패턴 사용 (sheet 재표시 시 중복 초기화 방지)
- **서비스 인스턴스**: View 내 서비스는 한 번만 생성하여 여러 호출에 공유
- **EffortCategory switch**: `default:` 대신 exhaustive case (`...3`, `9...`) — 새 case 추가 시 컴파일러 경고 보장
- **contextItem label**: `String` 아닌 `LocalizedStringKey`로 받아 자동 번역 보장

## Files Changed

| 파일 | 변경 |
|------|------|
| `Domain/Models/WorkoutIntensity.swift` | EffortCategory, EffortSuggestion 추가 |
| `Domain/UseCases/WorkoutIntensityService.swift` | suggestEffort() 추가 |
| `Presentation/Exercise/Components/EffortSliderView.swift` | 신규 |
| `Presentation/Exercise/Components/WorkoutCompletionSheet.swift` | 재설계 |
| `Presentation/Exercise/Components/IntensityBadgeView.swift` | effort 기반으로 리팩토링 |
| `Presentation/Exercise/Components/RPEInputView.swift` | 삭제 |
| `Presentation/Exercise/WorkoutSessionView.swift` | effort 연동 |
| `Presentation/Exercise/CompoundWorkoutView.swift` | API 갱신 |
| `Presentation/Shared/Extensions/WorkoutIntensity+View.swift` | EffortCategory UI 추가 |
| `Presentation/Exercise/ExerciseHistoryViewModel.swift` | effort 메트릭 추가 |
| `DUNETests/WorkoutIntensityServiceTests.swift` | 15 tests 추가 |
