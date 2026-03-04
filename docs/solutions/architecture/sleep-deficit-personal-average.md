---
tags: [sleep, deficit, personal-average, healthkit, use-case, dual-baseline]
date: 2026-03-04
category: solution
status: implemented
---

# Solution: 수면 부족 분석 개인화 (평균 수면시간 대비)

## Problem

기존 수면 분석은 고정 기준(7-9h ideal)으로 점수를 계산하여 개인 수면 패턴을 반영하지 못했다.
사용자의 실제 수면 히스토리를 기반으로 개인 평균 대비 부족분을 분석해야 했다.

## Solution

### 이중 기준선 (Dual Baseline)

- **14일 단기 평균**: 최근 수면 패턴 반영 (최소 3일 데이터 필요)
- **90일 장기 평균**: 계절/생활 변화 반영 (최소 7일 데이터 필요, 미달시 nil)

### 핵심 결정사항

| 결정 | 선택 | 근거 |
|------|------|------|
| 제로 데이터 일 | 평균에서 제외 | 센서 미착용 추정, 패널티 부과 불합리 |
| 초과 수면 상환 | 당일 부채만 0으로 | 과거일 소급 상환은 수면 과학적 근거 부족 |
| 부채 기간 | 7일 누적 | 1주 단위 분석이 임상적으로 유의미 |
| 기존 SleepScore | 변경 없음 | 7-9h ideal은 일반 건강 지표로 유지 |

### 아키텍처

```
Domain/Models/SleepDeficitAnalysis.swift       ← 결과 모델
Domain/UseCases/CalculateSleepDeficitUseCase.swift ← 순수 로직
Presentation/Shared/Extensions/SleepDeficitAnalysis+View.swift ← Color/Label 매핑
Presentation/Sleep/SleepDeficitGaugeView.swift ← 상세 화면 반원 게이지
Presentation/Dashboard/Components/SleepDeficitBadgeView.swift ← Today 탭 뱃지
```

### DayDuration 매핑 패턴

`fetchDailySleepDurations` 반환 튜플을 `DayDuration`으로 변환 시, convenience init으로 중앙화:

```swift
extension CalculateSleepDeficitUseCase.Input.DayDuration {
    init(from raw: (date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])) {
        self.init(date: raw.date, totalMinutes: raw.totalMinutes)
    }
}
```

3개 ViewModel에서 `.map(DayDuration.init(from:))`로 호출.

### DeficitLevel 매핑 패턴

Color/Label 매핑은 `SleepDeficitAnalysis+View.swift`에서 단일 소스:

```swift
extension SleepDeficitAnalysis.DeficitLevel {
    var color: Color { ... }
    var label: String { ... }
}
```

## Prevention

- **새 DeficitLevel 추가 시**: `SleepDeficitAnalysis+View.swift`의 color/label 매핑 동시 업데이트
- **새 ViewModel에서 deficit 사용 시**: `DayDuration.init(from:)` convenience init 사용 (toDayDuration 클로저 복사 금지)
- **수면 데이터 fetch 시**: Correction #115 준수 (fetch window >= filter threshold x 2)
