---
tags: [personal-record, 1rm, epley, rep-max, volume, strength, chart, activity-tab]
date: 2026-03-28
category: architecture
status: implemented
---

# Personal Record System: 1RM, Rep-Max, Volume PR 확장

## Problem

기존 PR 시스템은 운동별 평균 중량만 추적 (totalWeight / setCount). 1RM 추정, 렙 레인지별 최고 중량, 세션 총 볼륨 등 표준적인 strength PR 메트릭이 없어서 성장 추적이 제한됨.

PR 상세 화면도 단순 PointMark 차트만 제공하고, 기간 선택이 없어 시간에 따른 추이를 볼 수 없었음.

## Solution

### 1. Domain 모델 확장

**StrengthPersonalRecord** — 기존 `maxWeight`에 추가:
- `estimated1RM: Double?` + `estimated1RMDate: Date?` — Epley 1RM
- `repMaxEntries: [RepMaxEntry]` — 렙수별(3/5/10) 최고 중량
- `bestSessionVolume: Double?` + `bestSessionVolumeDate: Date?` — 세션 총 볼륨

**ActivityPersonalRecord.Kind** — 3개 case 추가:
- `.estimated1RM` (sortOrder 0, 최우선 표시)
- `.repMax` (sortOrder 1, subtitle에 "3RM"/"5RM"/"10RM")
- `.sessionVolume` (sortOrder 2)

### 2. Set-level 데이터 파이프라인

```
WorkoutSet (SwiftData) → SetSnapshot (Domain) → StrengthPRService.SetEntry → PR 계산
```

- `ExerciseRecordSnapshot`에 `completedSetSnapshots: [SetSnapshot]` 추가
- `ExerciseRecord+Snapshot`에서 completedSets의 weight+reps 추출
- `ActivityViewModel`에서 SetEntry로 변환하여 StrengthPRService에 전달

### 3. PR 감지 로직 (StrengthPRService)

**1RM**: 각 세트에 `OneRMFormula.epley.estimate(weight:reps:)` 적용 (reps 1-10만, 정확도 보장). 운동별 전체 세션에서 최고 1RM 추적.

**Rep-Max**: `trackedRepCounts = [3, 5, 10]`에 해당하는 세트 중 최고 중량. 운동별 렙수별 독립 추적.

**Volume**: 세션별 Σ(weight × reps) 계산. 운동별 최고 세션 볼륨 추적.

### 4. UI: Period-based Timeline Chart

기존 MetricDetailView 패턴과 동일하게:
- `TimePeriod` 기반 period picker (M/6M/Y)
- LineMark + PointMark 조합 차트
- Current Best 히어로 카드
- `.id(period)` + `.transition(.opacity)` 전환

### 5. DRY: Shared Display Helpers

`formattedValue` / `unitLabel` computed property를 `ActivityPersonalRecord` / `Kind`에 추출하여 Section과 DetailView의 중복 제거.

## Key Design Decision: OneRMEstimationService 재사용

`OneRMEstimationService`가 이미 Epley/Brzycki/Lombardi를 구현하고 있었음. PR 시스템에서는 `OneRMFormula.epley.estimate()`만 직접 호출하여 경량 통합. 전체 `analyze(sessions:)` API는 ExerciseHistory 상세에서만 사용.

## Validation Ranges

| Kind | Min | Max | 근거 |
|------|-----|-----|------|
| estimated1RM | 0 | 750 | Epley가 500kg × 10reps에서 ~667 |
| repMax | 0 | 500 | 원시 weight 범위 |
| sessionVolume | 0 | 100,000 | 500kg × 200reps 극단값 |

## Prevention

- 새 `ActivityPersonalRecord.Kind` 추가 시 exhaustive switch 컴파일 에러로 모든 소비자가 처리됨
- `isValid()` 범위를 반드시 추가해야 merge에서 필터링됨
- `formattedValue` / `unitLabel` 단일 소스로 표시 일관성 보장

## Lessons Learned

1. **기존 1RM 인프라 활용**: `OneRMEstimationService`가 이미 있었으므로 새로 구현하지 않고 직접 호출
2. **Set-level 데이터 중요**: 평균 중량만으로는 정확한 PR 감지 불가. set-level snapshot이 핵심
3. **Chart 패턴 일관성**: 기존 MetricDetailView의 period picker + DotLineChart 패턴을 따르면 UX 일관성 확보
