---
tags: [heart-rate, recovery, cardio, healthkit, workout-detail]
date: 2026-03-11
category: plan
status: draft
---

# Plan: Heart Rate Recovery (HRR₁) 분석

## Problem Statement

운동 후 심박수 회복 속도(Heart Rate Recovery, HRR₁)는 심폐 능력의 핵심 지표이지만 현재 앱에서 제공하지 않음. Athlytic 등 경쟁 앱은 이미 제공 중.

## Success Criteria

1. HealthKit 운동 상세 화면에서 HR Recovery 값(bpm)이 표시됨
2. HRR₁ < 12 bpm 미만이면 "Low", > 20 bpm이면 "Good" 등급 표시
3. HR 데이터가 부족하면 graceful fallback (표시 안 함)
4. 기존 HeartRateQueryService 확장으로 구현 (새 서비스 없음)
5. 유닛 테스트 포함

## Architecture Decision: 계산 전용 (저장 안 함)

HRR₁은 HealthKit HR 샘플에서 **on-the-fly 계산**한다. ExerciseRecord에 필드를 추가하지 않는다.

**근거:**
- 스키마 마이그레이션 (V12→V13) 불필요
- 과거 운동도 소급 계산 가능
- HealthKit HR 샘플은 이미 쿼리하고 있음 (HeartRateQueryService)
- 계산 비용 무시할 수 있음 (샘플 수십 개)

## Affected Files

| 파일 | 변경 | 설명 |
|------|------|------|
| `DUNE/Domain/Models/HealthMetric.swift` | 수정 | `HeartRateRecovery` 모델 추가 |
| `DUNE/Data/HealthKit/HeartRateQueryService.swift` | 수정 | `fetchHeartRateRecovery(forWorkoutID:)` 추가 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailViewModel.swift` | 수정 | `heartRateRecovery` 프로퍼티 추가 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | 수정 | Recovery 표시 UI 추가 |
| `DUNETests/HeartRateRecoveryTests.swift` | 신규 | 순수 계산 로직 테스트 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | 새 문자열 en/ko/ja 추가 |

## Implementation Steps

### Step 1: HeartRateRecovery 모델 추가

`DUNE/Domain/Models/HealthMetric.swift`에 추가:

```swift
/// Heart rate recovery result computed from post-workout HR samples.
struct HeartRateRecovery: Sendable {
    /// Peak HR at or near workout end (bpm).
    let peakHR: Double
    /// HR measured ~60 seconds after workout end (bpm).
    let recoveryHR: Double
    /// HRR₁ = peakHR - recoveryHR (bpm).
    var hrr1: Double { peakHR - recoveryHR }

    enum Rating: Sendable {
        case low      // < 12 bpm
        case normal   // 12-20 bpm
        case good     // > 20 bpm
    }

    var rating: Rating {
        if hrr1 < 12 { return .low }
        if hrr1 > 20 { return .good }
        return .normal
    }
}
```

### Step 2: HeartRateQueryService 확장

`HeartRateQueryService`에 `fetchHeartRateRecovery(forWorkoutID:)` 메서드 추가.

**알고리즘:**
1. 운동 UUID로 HKWorkout 쿼리 → `endDate` 획득
2. `endDate - 60초` ~ `endDate + 120초` 범위의 HR 샘플 쿼리
3. `endDate - 60초` ~ `endDate` 범위에서 max HR = peakHR
4. `endDate + 45초` ~ `endDate + 75초` 범위에서 평균 HR = recoveryHR (60초 ± 15초 윈도우)
5. 둘 다 유효하면 `HeartRateRecovery` 반환, 아니면 nil

**엣지 케이스:**
- Post-workout HR 샘플이 없는 경우 → nil 반환 (일부 디바이스/설정)
- peakHR < recoveryHR (비정상) → nil 반환
- 샘플 간격이 5분 이상 → 해당 샘플 무시

**프로토콜 확장:**
`HeartRateQuerying` 프로토콜에 `fetchHeartRateRecovery` 추가.

### Step 3: ViewModel 연동

`HealthKitWorkoutDetailViewModel`에:
- `var heartRateRecovery: HeartRateRecovery?` 프로퍼티 추가
- `loadDetail(workoutID:)` 내 `async let` 에 recovery 쿼리 추가

### Step 4: UI 표시

`HealthKitWorkoutDetailView`의 `heartRateSection` 하단에 Recovery 행 추가:
- HRR₁ 값 (bpm) + Rating 라벨
- Rating별 색상: low=red, normal=yellow, good=green
- HR 데이터 없으면 숨김

### Step 5: Localization

`Localizable.xcstrings`에 추가:
- "Recovery" → ko:"회복", ja:"リカバリー"
- "Low" → ko:"낮음", ja:"低い"
- "Normal" → ko:"보통", ja:"普通"
- "Good" → ko:"좋음", ja:"良い"

### Step 6: 유닛 테스트

`DUNETests/HeartRateRecoveryTests.swift`:
- 정상 케이스: peak 160, recovery 130 → HRR₁ = 30, rating = good
- 경계값: HRR₁ = 12 (normal), HRR₁ = 20 (normal → 초과해야 good)
- 낮은 회복: HRR₁ = 8 → low
- 비정상: peak < recovery → nil
- 빈 샘플 → nil

## Test Strategy

| 테스트 종류 | 대상 | 방법 |
|------------|------|------|
| 유닛 테스트 | HeartRateRecovery 모델 | rating 경계값 |
| 유닛 테스트 | 계산 로직 (static func) | 다양한 샘플 배열 입력 |
| 빌드 검증 | 전체 | scripts/build-ios.sh |

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| Apple Watch가 운동 후 HR 수집을 즉시 중단할 수 있음 | 60초 윈도우에 샘플이 없으면 nil (graceful) |
| AirPods는 운동 후 HR을 수집하지 않을 수 있음 | 동일하게 nil fallback |
| 극단적 HR 값 (센서 오류) | 기존 20-300 bpm 검증 재사용 |
| post-workout 샘플이 다른 운동과 겹칠 수 있음 | endDate 기준 ±2분 제한으로 범위 한정 |

## Alternatives Considered

1. **ExerciseRecord에 heartRateRecovery 필드 추가** — 스키마 마이그레이션 필요, 과거 데이터 소급 불가. 기각.
2. **별도 HeartRateRecoveryService 생성** — 단일 메서드라 서비스 분리는 과잉. HeartRateQueryService 확장이 적절.
