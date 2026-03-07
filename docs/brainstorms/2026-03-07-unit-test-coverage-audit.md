---
tags: [testing, coverage, audit, unit-test]
date: 2026-03-07
category: brainstorm
status: reviewed
---

# Brainstorm: Unit 테스트 전수 조사 및 누락 보완

## Problem Statement

프로젝트의 unit 테스트 전수 조사를 통해:
1. 테스트가 누락된 모델/서비스/UseCase 식별
2. 기존 테스트의 정확성 검증
3. 누락된 테스트 추가 및 잘못된 테스트 수정

## 현황 (2026-03-07)

- **기존 테스트**: 1,393개 전체 통과 (0 실패)
- **iOS 테스트 파일**: 119개 (DUNETests)
- **Watch 테스트 파일**: 10개 (DUNEWatchTests)
- **UI 테스트 파일**: 10개 (DUNEUITests + DUNEWatchUITests)
- **잘못된 테스트**: 없음 (전체 통과)

## 누락된 테스트 — iOS (직접 추가 가능)

### HIGH Priority

#### 1. HeartRateZone.swift — `computeZones` 알고리즘
- `WatchHRZoneTests`가 `estimateMaxHR`, `zone(forFraction:)` 커버
- **누락**: `computeZones(samples:maxHR:)` — interval 기반 zone 분배 알고리즘
- 테스트 케이스:
  - empty samples → 모든 zone 0%
  - single sample → 모든 zone 0%
  - 두 sample 같은 zone → 해당 zone 100%
  - 여러 zone 분산 → 올바른 비율
  - gap > 300s → skip
  - maxHR == 0 → 모든 zone 0%
  - NaN/Infinity percentage 방어
- **예상**: ~8 테스트

#### 2. ConditionScore.narrativeMessage — 8개 분기 경로
- `ConditionScoreTests`가 `BaselineStatus`, `ConditionStatus` 커버
- **누락**: `narrativeMessage` computed property (status × detail × HRV/RHR 조합)
- 테스트 케이스:
  - detail == nil → status.guideMessage fallback (5개 status)
  - excellent + HRV above baseline
  - excellent + HRV below baseline
  - good + rhrPenalty > 5
  - good + rhrPenalty ≤ 5
  - fair + HRV below baseline
  - fair + HRV above baseline
  - tired → 고정 메시지
  - warning → 고정 메시지
- **예상**: ~9 테스트

#### 3. MuscleFatigueState.swift — 상태 판정 로직
- 기존 테스트: 없음 (fixture로만 사용)
- 테스트 케이스:
  - fatigueLevel: compoundScore 있으면 → compound level 사용
  - fatigueLevel: compoundScore nil + lastTrainedDate nil → `.noData`
  - fatigueLevel: compoundScore nil + recoveryPercent 1.0 → fullyRecovered
  - fatigueLevel: compoundScore nil + recoveryPercent 0.0 → overtrained
  - isRecovered: rawValue ≤ 3 → true, 4 → false
  - isOverworked: rawValue ≥ 8 → true, 7 → false
  - nextReadyDate: lastTrainedDate nil → nil
  - nextReadyDate: already recovered → nil
  - nextReadyDate: recovery pending → valid future date
  - nextReadyDate: recoveryHours non-finite → nil
- **예상**: ~10 테스트

### MEDIUM Priority

#### 4. TrainingVolume.PeriodComparison — percentage change
- 기존 테스트: ViewModel/Service 테스트에서 fixture로만 사용
- 테스트 케이스:
  - durationChange: previous nil → nil
  - durationChange: previous totalDuration 0 → nil
  - durationChange: 정상 계산 (증가/감소)
  - calorieChange: 동일 패턴
  - sessionChange: Int→Double 변환 + 0 방어
  - activeDaysChange: 동일 패턴
  - DailyVolumePoint.totalDuration: empty segments, multiple segments
- **예상**: ~8 테스트

#### 5. StrengthPersonalRecord.swift — clamping + isRecent
- 기존 테스트: fixture로만 사용, clamping/isRecent 미검증
- 테스트 케이스:
  - maxWeight clamping: negative → 0, normal → unchanged, >500 → 500, 경계값 0/500
  - isRecent: 7일 이내 → true, 8일 → false, 오늘 → true
- **예상**: ~6 테스트

#### 6. InjuryInfo.swift — isActive, durationDays
- 기존 테스트: UseCase/Service 테스트에서 fixture로만 사용
- 테스트 케이스:
  - isActive: endDate nil → true, endDate non-nil → false
  - durationDays: same day → 0, multi-day → correct, active injury → days since start
- **예상**: ~5 테스트

### LOW Priority

#### 7. WeatherSnapshot.swift — threshold 프로퍼티
- `OutdoorFitnessScoreTests`가 `calculateOutdoorScore` 커버
- **누락**: `isStale`, `isExtremeHeat`, `isFreezing`, `isHighUV`, `isHighHumidity`, `isFavorableOutdoor`
- **예상**: ~6 테스트

#### 8. ActivityPersonalRecord.Kind — init 매핑
- 기존 테스트: 없음
- **누락**: `Kind.init?(personalRecordType:)` 5개 case 매핑
- **예상**: ~2 테스트

## 누락된 테스트 — Watch (리팩토링 필요)

### P2: WorkoutManager 순수 로직 추출

현재 `@MainActor @Observable` 클래스에 묶여 있어 직접 테스트 불가.
추출 → 테스트 패턴 (기존 `WorkoutElapsedTime`, `WatchSetInputPolicy` 선례):

| 추출 대상 | 현재 위치 | 추출 형태 | 예상 테스트 |
|-----------|----------|----------|------------|
| `formattedPace` | WorkoutManager | static func / enum | ~3 |
| `completeSet` validation | WorkoutManager | Policy struct | ~4 |
| `exerciseVolume` | SessionSummaryView | static func | ~3 |
| `perExerciseAllocation` | SessionSummaryView | static func | ~3 |

**총 예상**: ~13 테스트 (리팩토링 후)

### P3: WatchConnectivity 메시지 검증

- rest seconds range validation: `isFinite && (15...600).contains`
- theme normalization
- 대부분 기존 Policy 테스트로 커버 → 추가 가치 낮음
- **예상**: ~3 테스트

## Scope

### MVP (이번 작업)
- iOS HIGH + MEDIUM + LOW 테스트 추가 (8개 파일, ~54 테스트)
- Watch `computeZones` 테스트 추가 (shared domain model이므로 DUNETests에 추가)

### Future (별도 작업)
- Watch WorkoutManager 로직 추출 + 테스트 (~13 테스트, 리팩토링 수반)
- WatchConnectivity 메시지 검증 추출 (~3 테스트)

## 총 예상 작업량

| 구분 | 파일 수 | 테스트 수 |
|------|--------|----------|
| iOS 새 테스트 파일 | 6개 신규 + 2개 기존 확장 | ~54 |
| Watch 리팩토링+테스트 | 별도 TODO | ~16 |

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성 (MVP 범위)
- [ ] Watch 리팩토링은 별도 TODO로 분리
