---
tags: [workout, intensity, effort, slider, apple-fitness, training-load]
date: 2026-03-02
category: plan
status: draft
---

# Plan: 운동 강도 입력 전면 재설계

## Overview

현재 분리된 RPE(1-10 이모지 버튼) + autoIntensityRaw(0.0-1.0 배지)를 통합된 Effort 시스템으로 재설계한다.
Apple Fitness의 Effort Rating을 참고하여 슬라이더 UX + 자동 추천 + 히스토리 컨텍스트를 제공한다.

## Key Design Decision: `rpe` 필드 재활용

**스키마 변경 없이** 기존 `ExerciseRecord.rpe: Int?` 필드를 unified effort로 재활용한다.
- 기존 `rpe` → UI 라벨을 "Effort"로 변경, 값 범위 동일 (1-10)
- `autoIntensityRaw` → 내부 계산용으로 유지, effort 추천값 변환에 사용
- `effortSource` 추적 → 향후 별도 필드로 분리 가능 (MVP에서는 생략)

**장점**: 스키마 변경 없음, 기존 TrainingLoadService 호환, 마이그레이션 불필요

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `Domain/Models/WorkoutIntensity.swift` | 수정 | `EffortCategory` enum 추가 |
| `Domain/UseCases/WorkoutIntensityService.swift` | 수정 | `suggestEffort()` 메서드 추가 |
| `Presentation/Exercise/Components/EffortSliderView.swift` | 신규 | 1-10 슬라이더 컴포넌트 |
| `Presentation/Exercise/Components/WorkoutCompletionSheet.swift` | 수정 | 전면 재설계 |
| `Presentation/Exercise/Components/RPEInputView.swift` | 삭제 | EffortSliderView로 대체 |
| `Presentation/Exercise/Components/IntensityBadgeView.swift` | 수정 | Effort 기반 리팩토링 |
| `Presentation/Shared/Extensions/WorkoutIntensity+View.swift` | 수정 | EffortCategory UI 속성 추가 |
| `Presentation/Exercise/WorkoutSessionView.swift` | 수정 | completion sheet 연동 변경 |
| `Presentation/Exercise/ExerciseHistoryViewModel.swift` | 수정 | Effort 메트릭 추가 |
| `Presentation/Exercise/ExerciseHistoryView.swift` | 수정 | Effort 추이 표시 |
| `Resources/Localizable.xcstrings` | 수정 | 새 문자열 en/ko/ja |
| `DUNETests/WorkoutIntensityServiceTests.swift` | 수정 | suggestEffort 테스트 추가 |

## Implementation Steps

### Step 1: Domain — EffortCategory + suggestEffort()

**1a. `WorkoutIntensity.swift`에 EffortCategory 추가**

```swift
/// 4-level effort classification (Apple Fitness style)
enum EffortCategory: Int, CaseIterable, Sendable {
    case easy = 1      // Effort 1-3
    case moderate = 2  // Effort 4-6
    case hard = 3      // Effort 7-8
    case allOut = 4    // Effort 9-10

    init(effort: Int) {
        switch effort {
        case 1...3: self = .easy
        case 4...6: self = .moderate
        case 7...8: self = .hard
        default: self = .allOut
        }
    }
}

/// Effort suggestion result returned by suggestEffort()
struct EffortSuggestion: Sendable {
    let suggestedEffort: Int         // 1-10
    let category: EffortCategory
    let lastEffort: Int?             // 이전 세션 effort (nil if first)
    let averageEffort: Double?       // 최근 5회 평균 (nil if insufficient)
}
```

**1b. `WorkoutIntensityService.swift`에 `suggestEffort()` 추가**

```swift
/// Convert autoIntensityRaw (0.0-1.0) to effort (1-10) with history calibration.
func suggestEffort(
    autoIntensityRaw: Double?,
    recentEfforts: [Int]  // 최근 5회 사용자 effort (newest first)
) -> EffortSuggestion? {
    guard let raw = autoIntensityRaw, raw.isFinite, (0...1).contains(raw) else {
        // No auto intensity — return history-based suggestion if available
        return historyOnlySuggestion(recentEfforts: recentEfforts)
    }

    // Convert 0.0-1.0 → 1-10
    var suggested = Int(round(raw * 9.0)) + 1
    suggested = max(1, min(10, suggested))

    // History calibration: if user consistently rates higher/lower, adjust
    let validEfforts = recentEfforts.filter { (1...10).contains($0) }
    if validEfforts.count >= 3 {
        let userAvg = Double(validEfforts.reduce(0, +)) / Double(validEfforts.count)
        let autoAvg = Double(suggested) // single point calibration
        let bias = userAvg - autoAvg
        if abs(bias) >= 1.0 {
            suggested = max(1, min(10, suggested + Int(round(bias * 0.5))))
        }
    }

    return EffortSuggestion(
        suggestedEffort: suggested,
        category: EffortCategory(effort: suggested),
        lastEffort: validEfforts.first,
        averageEffort: validEfforts.isEmpty ? nil : Double(validEfforts.reduce(0, +)) / Double(validEfforts.count)
    )
}
```

### Step 2: EffortSliderView (신규)

Apple Fitness 스타일 슬라이더. 주요 특징:
- 큰 숫자 + 카테고리명 중앙 표시
- Slider (1-10, 정수 스냅)
- 카테고리 레이블 (Easy / Moderate / Hard / All Out)
- 히스토리 컨텍스트 (Last time, Average)
- 레벨별 색상 그라데이션

### Step 3: WorkoutCompletionSheet 재설계

레이아웃 변경:
- 상단: 체크마크 + "Workout Complete!" + 운동명/세트수
- 중단: EffortSliderView (suggested effort 기본값)
- 하단: Share + Done 버튼

기존 IntensityBadgeView와 RPEInputView를 EffortSliderView로 통합.

### Step 4: IntensityBadgeView → EffortBadgeView

히스토리/목록에서 사용하는 컴팩트 배지를 Effort 기반으로 변경:
- Effort 숫자 (1-10) + 카테고리명
- 색상 코딩 (Easy=green, Moderate=yellow, Hard=orange, AllOut=red)

### Step 5: WorkoutSessionView 연동

- `calculateAutoIntensity()` 결과로 `suggestEffort()` 호출
- 히스토리에서 최근 5회 rpe 값 수집
- WorkoutCompletionSheet에 suggestion 전달
- 사용자 확정값을 `record.rpe`에 저장

### Step 6: ExerciseHistory에 Effort 추이 추가

- `ProgressMetric`에 `.effort` case 추가
- `SessionSummary`의 기존 `autoIntensity`와 함께 `effort` 필드 추가 (record.rpe)
- 차트에 Effort 트렌드 라인 표시

### Step 7: Localization

새 문자열을 `Localizable.xcstrings`에 en/ko/ja 추가:
- "How did it feel?" / "어떠셨나요?" / "どうでしたか？"
- "Easy" / "쉬움" / "楽"
- "Moderate" / "보통" / "普通"
- "Hard" / "힘듦" / "きつい"
- "All Out" / "전력" / "全力"
- "Last time" / "지난번" / "前回"
- "Average" / "평균" / "平均"
- "Effort" / "강도" / "強度"

### Step 8: Unit Tests

`WorkoutIntensityServiceTests.swift`에 추가:
- `suggestEffort` 정상 변환 (0.0→1, 0.5→6, 1.0→10)
- 히스토리 calibration 적용
- autoIntensityRaw nil → history-only fallback
- 빈 히스토리 → nil 반환
- 경계값 (0.0, 1.0, negative, >1.0)

## Verification

1. 빌드: `scripts/build-ios.sh`
2. 테스트: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests -quiet`
3. 수동 검증: 운동 완료 → 슬라이더 표시 + 자동 추천값 확인
