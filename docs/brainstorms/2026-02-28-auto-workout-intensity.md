---
tags: [workout, intensity, auto-scoring, 1rm, training-zones, analytics]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: Auto Workout Intensity Scoring System

## Problem Statement

운동이 기록되면 해당 세트/세션이 사용자의 과거 퍼포먼스 대비 **얼마나 강했는지**를 자동으로 산출하는 시스템이 필요하다.

현재 DUNE에는:
- **RPE** (1-10): 사용자가 수동 입력하는 주관적 강도 → 입력률 저조, 일관성 부족
- **VolumeIntensity** (5단계): 주간 세트 수 기반 → "볼륨"이지 "강도"가 아님
- **OneRMEstimationService**: 1RM 추정값은 있으나 세트별 강도 비율로 환산하지 않음
- **FatigueCalculationService**: 근육 피로도는 계산하나 "이 세트가 얼마나 힘들었는지"는 아님

**Gap**: 세트/세션 단위의 통합 강도 점수가 없어, 사용자는 "오늘 운동이 평소보다 강했는지/약했는지"를 직관적으로 파악할 수 없다.

## Target Users

- **주 사용자**: 주 3-5회 운동하는 중급자 — 과거 기록 대비 진보를 추적하고 싶음
- **초보자**: 데이터가 부족하지만 RPE fallback으로 최소한의 강도 표시 필요
- **고급자**: 정밀한 1RM 대비 % + Training Zone 피드백 기대

## Success Criteria

1. 운동 완료 후 **세션 요약**에 5단계 강도 라벨이 자동 표시됨
2. 사용자 입력 없이 weight/reps/duration/distance 데이터만으로 산출 가능
3. 모든 운동 유형(근력/맨몸/유산소/유연성/HIIT)에 적용됨
4. 히스토리에서 시간 경과에 따른 강도 트렌드를 차트로 확인 가능
5. RPE 입력이 있으면 자동 산출값과 가중 결합하여 정확도 향상

## Proposed Approach

### 강도 산출 공식 (운동 유형별)

#### 1. 근력 운동 (setsRepsWeight)

**Primary Signal: Estimated 1RM 대비 %**

```
setIntensity = (weight / estimated1RM) × 100
```

- `estimated1RM`: OneRMEstimationService에서 최근 30일 기록 기반 산출
- 1RM 데이터 없으면 → 히스토리 percentile fallback

**Secondary Signal: Volume Load 대비**

```
sessionVolumeLoad = Σ(weight × reps) per set
relativeVolume = sessionVolumeLoad / avg(last10Sessions.volumeLoad)
```

**결합**:
```
rawIntensity = 0.6 × (avgSetIntensity / 100) + 0.3 × min(relativeVolume, 1.5) + 0.1 × (rpe / 10)
```

#### 2. 맨몸 운동 (setsReps)

**Primary Signal: Reps percentile**

```
repPercentile = currentReps.rank(in: last30DaysReps) / total
```

- 과거 30일 동일 운동의 reps 분포에서 현재 세트의 위치

**Secondary Signal: Volume 대비**

```
sessionTotalReps = Σ reps
relativeVolume = sessionTotalReps / avg(last10.totalReps)
```

#### 3. 유산소 운동 (durationDistance)

**Primary Signal: Pace/Speed percentile**

```
pace = duration / distance
pacePercentile = pace.rank(in: last30DaysPaces) / total  // 낮을수록 강함
intensityFromPace = 1 - pacePercentile  // 반전
```

**Secondary Signal: Duration 대비**

```
relativeDuration = currentDuration / avg(last10.duration)
```

**결합**:
```
rawIntensity = 0.5 × intensityFromPace + 0.3 × min(relativeDuration, 1.5) + 0.2 × (hrZone / 5)
```

#### 4. 유연성/HIIT (durationIntensity, roundsBased)

**Primary Signal: 기존 intensity 필드 (1-10) → 정규화**

```
rawIntensity = setIntensity / 10
```

**Duration 가중**:
```
relativeDuration = currentDuration / avg(last10.duration)
adjusted = rawIntensity × min(relativeDuration, 1.2)
```

### 5단계 라벨 매핑

| Raw Score | Label | 한국어 | Color |
|-----------|-------|--------|-------|
| 0.0 - 0.2 | Very Light | 매우 가벼움 | DS.Color.positive (green) |
| 0.2 - 0.4 | Light | 가벼움 | DS.Color.info (blue) |
| 0.4 - 0.6 | Moderate | 보통 | DS.Color.caution (yellow) |
| 0.6 - 0.8 | Hard | 강함 | DS.Color.warning (orange) |
| 0.8 - 1.0 | Max Effort | 최대 | DS.Color.negative (red) |

### RPE 가중 결합

RPE가 입력된 경우:
```
finalScore = 0.7 × autoScore + 0.3 × (rpe / 10)
```

RPE가 없는 경우:
```
finalScore = autoScore
```

### 히스토리 부족 시 Fallback 전략

| 데이터 상태 | 전략 |
|-------------|------|
| 1RM + 10+ 세션 | Full formula (1RM% + volume + RPE) |
| 5-9 세션 | Volume percentile + RPE |
| 1-4 세션 | RPE only (있으면) 또는 "데이터 수집 중" |
| 0 세션 (첫 운동) | RPE only 또는 표시 안 함 |

## Architecture

### Domain Layer

```
Domain/Models/
├── WorkoutIntensity.swift          // 5-level enum + raw score
├── WorkoutIntensityDetail.swift    // 중간 계산값 (디버깅용, Correction #113)

Domain/UseCases/
├── WorkoutIntensityService.swift   // 핵심 산출 로직
```

### Data Flow

```
ExerciseRecord 저장 완료
  → WorkoutIntensityService.calculateIntensity(
      record: ExerciseRecordSnapshot,
      history: [ExerciseRecordSnapshot],  // 같은 운동 최근 30일
      estimated1RM: Double?,              // OneRMEstimationService에서
      rpe: Int?
    )
  → WorkoutIntensity (5단계 + rawScore 0-1)
  → ExerciseRecord.autoIntensityRaw 에 저장 (Double, 0-1)
```

### 기존 시스템과의 관계

| 기존 시스템 | 관계 |
|-------------|------|
| OneRMEstimationService | **Input**: 1RM 추정값을 강도 계산에 활용 |
| FatigueCalculationService | **Independent**: 피로도는 별도 시스템. 강도가 피로 입력으로 사용될 수 있음 (향후) |
| RPEInputView | **Input**: 사용자 RPE를 가중치로 결합 |
| VolumeIntensity | **Replace partially**: 주간 볼륨 강도와 세션 강도는 별개 지표 |
| TrainingVolumeAnalysisService | **Input**: 과거 볼륨 데이터 참조 |

## Constraints

### 기술적 제약
- **SwiftData 스키마 변경**: `ExerciseRecord`에 `autoIntensityRaw: Double?` 필드 추가 → CloudKit 마이그레이션 고려 (Correction #32, #33)
- **계산 비용**: 30일 히스토리 로드 + 1RM 계산은 세션 저장 시 1회만 수행. body에서 반복 호출 금지 (Correction #111)
- **Domain 레이어 순수성**: WorkoutIntensityService는 Foundation만 import (Correction #1)

### 데이터 제약
- 초보 사용자는 1RM 데이터 부족 → percentile fallback 필수
- HealthKit 동기화 워크아웃은 세트 데이터 없음 → 전체 세션 메트릭(duration, calories, HR)으로 산출
- Watch 워크아웃도 동일 강도 산출 적용 필요 (향후)

## Edge Cases

1. **첫 운동 (히스토리 0)**: 강도 표시 안 함 또는 RPE만 사용
2. **장기 휴식 후 복귀**: 30일 히스토리가 부재 → 전체 히스토리에서 가장 최근 10세션 사용
3. **극단적 세트 (weight=0 or reps=1000)**: 입력 검증 범위 내에서만 산출 (Correction #22)
4. **운동 종류 변경**: 같은 운동명이지만 다른 장비 → exerciseDefinitionID 기반 매칭
5. **1RM 급격한 변화**: 부상 복귀 등으로 1RM이 크게 하락 → 최근 7일 가중 평균 사용
6. **유산소 거리 0**: duration-only fallback (Correction #79)
7. **NaN/Infinite 결과**: 모든 나눗셈/log 결과에 isFinite guard (Correction #18)

## Scope

### MVP (Must-have)
- [ ] `WorkoutIntensity` 5단계 enum + rawScore 모델
- [ ] `WorkoutIntensityService` — 운동 유형별 강도 산출 로직
- [ ] `ExerciseRecord.autoIntensityRaw` 필드 추가
- [ ] 세션 완료 시 자동 산출 + 저장
- [ ] 세션 요약 화면에 강도 라벨 + 색상 표시
- [ ] 히스토리 뷰에서 강도 트렌드 라인 차트
- [ ] 단위 테스트 (경계값, 0 히스토리, NaN 방어)

### Nice-to-have (Future)
- [ ] 세트별 강도 표시 (운동 중 실시간)
- [ ] 강도 기반 운동 추천 ("오늘은 Light day 추천")
- [ ] FatigueCalculationService에 강도 데이터 연동
- [ ] Watch에서 강도 표시
- [ ] 주간/월간 강도 분포 차트 (Light 40%, Moderate 30%, ...)
- [ ] HealthKit effortScore와 교차 검증

## Open Questions

1. ~~강도 기준~~ → **복합 (1RM + 히스토리 + RPE)** 결정됨
2. ~~출력 형태~~ → **5단계 라벨** 결정됨
3. ~~적용 범위~~ → **전체 운동 유형** 결정됨
4. ~~활용 위치~~ → **세션 요약 + 히스토리 차트** 결정됨
5. `autoIntensityRaw`를 매번 재계산 vs 저장 후 캐싱? → 저장 권장 (히스토리가 바뀌면 과거 강도도 바뀌는 문제 방지)
6. HealthKit 동기화 워크아웃(세트 데이터 없음)에도 강도를 산출할 것인가? → MVP에서는 제외 가능

## Next Steps

- [ ] `/plan auto-workout-intensity` 로 구현 계획 생성
