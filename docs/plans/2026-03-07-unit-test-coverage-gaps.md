---
tags: [testing, coverage, unit-test, model]
date: 2026-03-07
category: plan
status: approved
---

# Plan: Unit 테스트 누락 보완

## Summary

brainstorm 전수 조사 결과 발견된 8개 소스 파일에 대한 누락 테스트 추가.
기존 1,393 테스트 전체 통과, 잘못된 테스트 없음 확인 완료.

## Affected Files

### 새로 생성할 테스트 파일

| # | 테스트 파일 | 대상 소스 | 예상 테스트 수 |
|---|-----------|----------|--------------|
| 1 | `DUNETests/HeartRateZoneCalculatorTests.swift` | `Domain/Models/HeartRateZone.swift` | ~8 |
| 2 | `DUNETests/MuscleFatigueStateTests.swift` | `Domain/Models/MuscleFatigueState.swift` | ~10 |
| 3 | `DUNETests/PeriodComparisonTests.swift` | `Domain/Models/TrainingVolume.swift` | ~8 |
| 4 | `DUNETests/StrengthPersonalRecordTests.swift` | `Domain/Models/StrengthPersonalRecord.swift` | ~6 |
| 5 | `DUNETests/InjuryInfoTests.swift` | `Domain/Models/InjuryInfo.swift` | ~5 |
| 6 | `DUNETests/WeatherSnapshotThresholdTests.swift` | `Domain/Models/WeatherSnapshot.swift` | ~6 |
| 7 | `DUNETests/ActivityPersonalRecordKindTests.swift` | `Domain/Models/ActivityPersonalRecord.swift` | ~3 |

### 기존 테스트 파일 확장

| # | 테스트 파일 | 추가 내용 | 예상 테스트 수 |
|---|-----------|----------|--------------|
| 8 | `DUNETests/ConditionScoreTests.swift` | `narrativeMessage` 분기 테스트 | ~9 |

## Implementation Steps

### Step 1: HeartRateZoneCalculatorTests.swift

`computeZones` 알고리즘 테스트. `WatchHRZoneTests`가 이미 `estimateMaxHR`, `zone(forFraction:)` 커버.

테스트 케이스:
- empty samples → 5 zones 모두 0
- single sample → 5 zones 모두 0
- 2 samples 같은 zone (zone3, 75% maxHR) → zone3 = 100%
- 여러 zone 분산 → 올바른 비율
- gap >= 300s → skip (zone에 포함 안됨)
- maxHR == 0 → 5 zones 모두 0
- bpm < 50% maxHR → zone 할당 안됨 (totalDuration 0 → 전부 0)
- bpm exactly 0.50 fraction → zone1

### Step 2: ConditionScoreTests.swift 확장 (narrativeMessage)

기존 `ConditionScoreTests`에 `narrativeMessage` 섹션 추가.

테스트 케이스:
- detail == nil → status.guideMessage (5개 status 각각)
- excellent + HRV above baseline → "Top shape"
- excellent + HRV below baseline → "Excellent recovery"
- good + rhrPenalty > 5 → "Good overall — RHR"
- good + rhrPenalty ≤ 5 → "Solid recovery"
- fair + HRV below baseline → "HRV below baseline"
- fair + HRV above baseline → "Moderate recovery"
- tired → "HRV significantly low"
- warning → "Recovery very low"

### Step 3: MuscleFatigueStateTests.swift

테스트 케이스:
- fatigueLevel: compoundScore 존재 → compound level 반환
- fatigueLevel: compoundScore nil + lastTrainedDate nil → `.noData`
- fatigueLevel: compoundScore nil + recoveryPercent 1.0 → fullyRecovered
- fatigueLevel: compoundScore nil + recoveryPercent 0.0 → overtrained/severe
- isRecovered: rawValue 3 → true, rawValue 4 → false
- isOverworked: rawValue 8 → true, rawValue 7 → false
- nextReadyDate: lastTrainedDate nil → nil
- nextReadyDate: already fully recovered → nil
- nextReadyDate: partially recovered → future date
- nextReadyDate: recoveryHours 0 → nil (guard fails)

### Step 4: PeriodComparisonTests.swift

테스트 케이스:
- durationChange: previous nil → nil
- durationChange: previous totalDuration 0 → nil
- durationChange: 100% 증가 (1000→2000) → 100.0
- durationChange: 50% 감소 → -50.0
- calorieChange: 동일 패턴
- sessionChange: Int→Double, 0 sessions → nil
- activeDaysChange: 동일 패턴
- DailyVolumePoint.totalDuration: empty → 0, multiple → sum

### Step 5: StrengthPersonalRecordTests.swift

테스트 케이스:
- maxWeight negative → 0
- maxWeight 250 → 250
- maxWeight 600 → 500
- maxWeight 0 → 0, maxWeight 500 → 500
- isRecent: 오늘 날짜 → true
- isRecent: 7일 전 → true (경계값)
- isRecent: 8일 전 → false

### Step 6: InjuryInfoTests.swift

테스트 케이스:
- isActive: endDate nil → true
- isActive: endDate non-nil → false
- durationDays: same day → 0
- durationDays: 5일 차이 → 5
- durationDays: active injury (endDate nil) → days since start

### Step 7: WeatherSnapshotThresholdTests.swift

테스트 케이스:
- isExtremeHeat: 34.9 → false, 35 → true
- isFreezing: 0.1 → false, 0 → true
- isHighUV: 7 → false, 8 → true
- isHighHumidity: 0.79 → false, 0.80 → true
- isFavorableOutdoor: 모든 조건 양호 → true
- isFavorableOutdoor: 하나라도 나쁨 → false

### Step 8: ActivityPersonalRecordKindTests.swift

테스트 케이스:
- isLowerBetter: fastestPace → true, 나머지 → false
- init from PersonalRecordType: 5개 매핑 + unmapped → nil
- sortOrder: 6개 순서 검증

## Test Strategy

- Framework: Swift Testing (`@Suite`, `@Test`, `#expect`)
- Pattern: Arrange / Act / Assert
- 모든 경계값, 0, nil, NaN/Infinity 테스트
- `@testable import DUNE`

## Risks & Edge Cases

- `narrativeMessage`는 `String(localized:)` 반환 → 테스트에서 영어 locale 기준 비교
- `MuscleFatigueState.nextReadyDate`는 시간 의존 → 고정 날짜로 테스트
- `InjuryInfo.durationDays`는 Calendar 의존 → active injury 테스트 시 고정 날짜 사용
- `WeatherSnapshot.isStale`는 시간 의존 → fetchedAt을 조작하여 테스트

## Verification

```bash
xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' \
  -only-testing DUNETests
```
