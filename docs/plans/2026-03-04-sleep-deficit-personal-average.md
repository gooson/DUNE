---
tags: [sleep, deficit, personal-average, wellness, healthkit]
date: 2026-03-04
category: plan
status: draft
---

# Plan: 수면 부족 분석 개인화 (평균 수면시간 대비)

## 목표

사용자의 14일/90일 수면 히스토리를 기반으로 개인 평균 수면시간을 계산하고,
이를 기준으로 7일 누적 수면 부채를 분석하여 Sleep 상세화면과 Today 탭에 표시한다.

## 사용자 결정 사항

- 데이터 없는 날(0분): 평균 계산에서 **제외** (센서 미착용 추정)
- 초과 수면 상환: **당일 부채만** 0으로 (과거일 소급 상환 없음)
- Today 탭 표시: **게이지** 형태

## Affected Files

| 파일 | 변경 | 설명 |
|------|------|------|
| `Domain/UseCases/CalculateSleepDeficitUseCase.swift` | **NEW** | 부채 계산 로직 |
| `Domain/Models/SleepDeficitAnalysis.swift` | **NEW** | 결과 모델 |
| `Data/HealthKit/SleepQueryService.swift` | **MODIFY** | 90일 데이터 fetch 메서드 추가 |
| `Presentation/Sleep/SleepViewModel.swift` | **MODIFY** | deficit 로드 + 캐싱 |
| `Presentation/Sleep/SleepDeficitGaugeView.swift` | **NEW** | 부채 게이지 UI |
| `Presentation/Shared/Detail/MetricDetailView.swift` | **MODIFY** | sleep 카테고리에 deficit 섹션 추가 |
| `Presentation/Dashboard/DashboardViewModel.swift` | **MODIFY** | deficit 요약 계산 + 캐싱 |
| `Presentation/Dashboard/Components/SleepDeficitBadgeView.swift` | **NEW** | Today 카드 내 게이지 뱃지 |
| `DUNETests/CalculateSleepDeficitUseCaseTests.swift` | **NEW** | UseCase 전 분기 테스트 |
| `DUNETests/SleepViewModelTests.swift` | **MODIFY** | deficit 로딩 테스트 추가 |

## Implementation Steps

### Step 1: Domain Model (SleepDeficitAnalysis)

`DUNE/Domain/Models/SleepDeficitAnalysis.swift` 생성:

```swift
struct SleepDeficitAnalysis: Sendable {
    let shortTermAverage: Double      // 14일 평균 (분)
    let longTermAverage: Double?      // 90일 평균 (분, 데이터 부족 시 nil)
    let weeklyDeficit: Double         // 7일 누적 부채 (분, 양수=부족)
    let dailyDeficits: [DailyDeficit] // 7일 일별 부족
    let level: DeficitLevel
    let dataPointCount: Int           // 14일 중 실제 데이터 있는 날 수

    struct DailyDeficit: Sendable {
        let date: Date
        let actualMinutes: Double
        let deficitMinutes: Double    // 양수=부족, 0=충분(초과도 0)
    }

    enum DeficitLevel: Sendable {
        case good          // < 2h
        case mild          // 2-5h
        case moderate      // 5-10h
        case severe        // > 10h
        case insufficient  // 데이터 3일 미만
    }
}
```

### Step 2: UseCase (CalculateSleepDeficitUseCase)

`DUNE/Domain/UseCases/CalculateSleepDeficitUseCase.swift` 생성:

```swift
protocol SleepDeficitCalculating: Sendable {
    func execute(input: CalculateSleepDeficitUseCase.Input) -> SleepDeficitAnalysis
}

struct CalculateSleepDeficitUseCase: SleepDeficitCalculating, Sendable {
    struct Input: Sendable {
        let recentDurations: [(date: Date, totalMinutes: Double)]  // 최근 14일
        let longTermDurations: [(date: Date, totalMinutes: Double)] // 최근 90일
    }
}
```

로직:
1. 0분 데이터 필터링 (센서 미착용)
2. 14일 평균 계산 (최소 3일 데이터 필요, 미만 시 `.insufficient`)
3. 90일 평균 계산 (최소 7일 데이터 필요, 미만 시 nil)
4. 최근 7일 일별 부채 = max(0, 14일평균 - 실제수면) → 초과 수면은 0
5. 7일 합산 → weeklyDeficit
6. DeficitLevel 분류

### Step 3: SleepQueryService 확장

기존 `fetchDailySleepDurations(start:end:)` 활용. 새 convenience 메서드:

```swift
// SleepQuerying protocol 추가
func fetchSleepDurationsForDeficit() async throws -> (recent14: [...], longTerm90: [...])
```

기존 메서드를 14일/90일 범위로 2회 호출 (async let 병렬화).

### Step 4: SleepViewModel 확장

```swift
// 추가 프로퍼티
private(set) var deficitAnalysis: SleepDeficitAnalysis?
private let deficitUseCase = CalculateSleepDeficitUseCase()

// loadData() 내 추가
// weeklyData fetch와 병렬로 deficit 데이터도 fetch
```

### Step 5: MetricDetailView sleep 섹션에 deficit 추가

`MetricDetailView`에서 `metric.category == .sleep` 일 때 Highlights 아래에 deficit 게이지 섹션 추가.
`MetricDetailViewModel`에 deficit 프로퍼티 추가.

### Step 6: SleepDeficitGaugeView (게이지 UI)

- 반원형 게이지 (0-10h+ 범위)
- 색상: good(녹), mild(노), moderate(주), severe(빨)
- 중앙: 누적 부채 시간 표시
- 하단: "14일 평균 vs 90일 평균" 비교 텍스트

### Step 7: Today 탭 연동

`DashboardViewModel`에서:
1. sleep metric fetch 시 함께 deficit 계산
2. `sleepDeficitLevel` 프로퍼티 추가
3. `SleepDeficitBadgeView`: Today 카드 내 작은 게이지 뱃지

### Step 8: 유닛 테스트

`CalculateSleepDeficitUseCaseTests`:
- 데이터 부족 (< 3일) → `.insufficient`
- 정상 수면 (부채 < 2h) → `.good`
- 경미한 부족 (2-5h) → `.mild`
- 중간 부족 (5-10h) → `.moderate`
- 심각한 부족 (> 10h) → `.severe`
- 0분 데이터 제외 검증
- 초과 수면 당일만 상환 검증
- 90일 데이터 부족 → longTermAverage nil
- 경계값 테스트 (정확히 2h, 5h, 10h)

## 구현 순서

1. Domain 모델 + UseCase (테스트 가능한 순수 로직)
2. UseCase 유닛 테스트
3. SleepQueryService 확장
4. SleepViewModel 통합
5. UI 컴포넌트 (게이지 + 뱃지)
6. MetricDetailView 통합
7. DashboardViewModel + Today 뱃지
8. 빌드 검증

## 제약 사항

- 기존 SleepScore(7-9h ideal) 변경 없음
- CoachingEngine 변경 없음 (Future scope)
- watchOS 표시 없음 (Future scope)
- Localization: 새 문자열 en/ko/ja 3개 언어 동시 추가
