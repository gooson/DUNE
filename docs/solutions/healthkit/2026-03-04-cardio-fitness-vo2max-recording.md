---
tags: [healthkit, vo2max, cardio-fitness, cardio-session, exercise-record]
date: 2026-03-04
category: solution
status: implemented
---

# 유산소 운동 시 VO2 Max (유산소 피트니스) 기록

## Problem

유산소 운동 완료 후 HealthKit에 존재하는 VO2 Max(유산소 피트니스) 데이터가 운동 기록에 캡처되지 않음.

### 근본 원인

- `CardioSessionViewModel`이 VO2 Max 데이터를 전혀 조회하지 않았음
- `CardioSessionRecord`와 `ExerciseRecord`에 VO2 Max 필드가 없었음
- `CardioSessionSummaryView`에 VO2 Max 표시/저장 로직이 없었음

## Solution

### 1. 데이터 모델 확장

`ExerciseRecord` (SwiftData):
```swift
var cardioFitnessVO2Max: Double?  // ml/kg/min
```

`CardioSessionRecord` (DTO):
```swift
let cardioFitnessVO2Max: Double?
```

스키마 버전: V9 → V10 (lightweight migration)

### 2. VO2 Max 조회 (VitalsQueryService 재사용)

`CardioSessionViewModel.end()` 완료 시 `VitalsQueryService.fetchLatestVO2Max(withinDays: 30)` 호출:

```swift
private func fetchCardioFitness() async {
    guard let vitalsService else { return }
    do {
        let sample = try await vitalsService.fetchLatestVO2Max(withinDays: 30)
        if let sample { cardioFitnessVO2Max = sample.value }
    } catch {
        // optional — keep nil on failure
    }
}
```

### 3. 범위 검증

저장 시점에서 `10.0...90.0 ml/kg/min` 범위 검증 (CloudKit 전파 방어):
```swift
cardioFitnessVO2Max: data.cardioFitnessVO2Max.flatMap { (10.0...90.0).contains($0) ? $0 : nil }
```

### 4. UI 표시

`CardioSessionSummaryView` 하단 카드로 표시:
- 아이콘: `heart.circle.fill`
- 색상: `DS.Color.heartRate`
- 단위: `ml/kg/min`

## Prevention

- 새 HealthKit 메트릭을 운동 기록에 추가할 때 체크리스트:
  1. `ExerciseRecord` 필드 추가 + 스키마 버전 증가
  2. DTO (`CardioSessionRecord` / `WorkoutWriteInput`) 필드 추가
  3. ViewModel에서 조회 + `createExerciseRecord()`에 포함
  4. View에서 표시 + 저장
  5. 범위 검증 (input-validation.md 참조)
  6. xcstrings 3개 언어 등록
  7. 유닛 테스트

## Affected Files

| 파일 | 변경 |
|------|------|
| `ExerciseRecord.swift` | `cardioFitnessVO2Max` 필드 |
| `AppSchemaVersions.swift` | V10 + migration |
| `CardioSessionViewModel.swift` | VO2Max fetch + record 포함 |
| `CardioSessionSummaryView.swift` | 표시 + 저장 + 범위 검증 |
| `Localizable.xcstrings` | "Cardio Fitness" 3개 언어 |
| `CardioSessionViewModelTests.swift` | 3개 테스트 케이스 |
