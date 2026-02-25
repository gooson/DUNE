---
tags: [body-score, wellness, fetch-range, dateComponents, calculation-card, computed-property-caching, DRY]
date: 2026-02-25
category: architecture
status: implemented
---

# Body Score "--" 표시 수정 + Body Calculation Card 추가

## Problem

### 증상
Wellness Score Detail에서 Body 점수가 항상 "--"로 표시됨. 사용자는 매주 4회 이상 체중 기록 중.

### 근본 원인
`fetchWeight(days: 7)`로 7일치만 가져온 뒤, `dateComponents([.day], from:to:) >= 6` 필터로 1주 전 데이터를 찾음.

`Calendar.dateComponents([.day])` 는 **정수 일 차이**(시간 truncation)를 반환하므로:
- `latestWeight` = 2/25 09:00, oldest history = 2/19 20:00
- 실제 차이 = 5일 13시간 → `.day` = **5** → 필터 탈락

7일 fetch window가 6일 필터 threshold와 시간 경계에서 충돌하여 대부분의 경우 `weightWeekAgo = nil`.

### 부가 문제
Body 점수가 어떻게 계산되는지 사용자에게 보여주는 UI가 없었음 (Condition은 `ConditionCalculationCard`가 존재).

## Solution

### 1. Fetch 범위 확장 (bb3fd71)
```swift
// Before
let history = try await bodyService.fetchWeight(days: 7)

// After — 14일로 확장하여 6일 필터 통과 보장
let history = try await bodyService.fetchWeight(days: 14)
```

### 2. BodyScoreDetail 모델 + BodyCalculationCard UI (4ffc966)

`ConditionScoreDetail` 패턴을 따라 중간 계산값을 노출:

- `BodyScoreDetail`: weightChange, weightLabel, weightPoints, baselinePoints, finalScore
- `BodyCalculationCard`: `ConditionCalculationCard`와 동일 패턴의 계산 breakdown 카드
- 파이프라인: `BodyTrend.detail` → `WellnessViewModel.bodyScoreDetail` → `WellnessScoreDetailView` → `BodyCalculationCard`

### 3. 리뷰 수정 (1f9df25)

| 이슈 | 수정 |
|------|------|
| P1: `detail` computed property 이중 계산 | ViewModel에서 1회 계산 후 `finalScore` 파생 |
| P2: `row()` 헬퍼 중복 | `CalculationRow` 공통 컴포넌트 추출 |
| P2: 분류 threshold 중복 | `BodyScoreDetail.TrendLabel` enum을 Domain에서 산출 |
| P3: `bodyFatChange` dead branch | 미구현 필드 제거 (항상 nil) |
| P3: `isFinite` guard 누락 | `weightChange` 입력에 `.isFinite` 체크 추가 |
| P3: init pre-cache 과잉 | `String(format:)` 는 NSObject formatter가 아니므로 inline 처리 |

### 변경 파일
- `Dailve/Domain/Models/BodyScoreDetail.swift` (신규)
- `Dailve/Domain/UseCases/CalculateWellnessScoreUseCase.swift`
- `Dailve/Presentation/Shared/Components/BodyCalculationCard.swift` (신규)
- `Dailve/Presentation/Shared/Components/CalculationRow.swift` (신규)
- `Dailve/Presentation/Shared/Components/ConditionCalculationCard.swift`
- `Dailve/Presentation/Wellness/WellnessScoreDetailView.swift`
- `Dailve/Presentation/Wellness/WellnessView.swift`
- `Dailve/Presentation/Wellness/WellnessViewModel.swift`

## Prevention

1. **Fetch window는 필터 threshold의 2배 이상**: `>= N일` 필터를 쓰면 fetch는 최소 `2N일`. `dateComponents` 시간 truncation 문제 방지
2. **Calculation Card는 score 추가 시 함께 구현**: 새 score 컴포넌트 추가 시 `{Type}ScoreDetail` + `{Type}CalculationCard` 세트로 작업
3. **Computed property 이중 접근 감시**: `.score`와 `.detail`을 각각 호출하면 2회 계산. caller에서 1회 계산 후 분배
4. **Dead branch 즉시 제거**: 미구현 필드(`bodyFatChange: nil`)가 UI까지 전파되면 "no data" 행이 혼란 유발

## Lessons Learned

1. `Calendar.dateComponents([.day])` 는 시간 truncation이 있어 "7일 전" 데이터가 `.day = 5`로 계산될 수 있음. 날짜 비교 시 항상 시간 버퍼를 고려해야 함
2. Correction #80 (formatter 캐싱)은 `NSObject` 기반 formatter에만 적용. `String(format:)`은 value operation이므로 pre-cache 불필요
3. 계산 breakdown UI는 score 알고리즘 디버깅에 필수 — 사용자와 개발자 모두에게 "왜 이 점수인지" 설명 가능
4. 공통 UI 패턴(`row` 헬퍼)이 2곳에서 확인되면 즉시 추출 — 3곳 규칙(#37)보다 `CalculationCard` 같은 확정 패턴은 2곳에서 추출이 적절
