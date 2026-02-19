---
tags: [ui, train-tab, exercise-tab, workout-row, redesign, consistency]
date: 2026-02-19
category: brainstorm
status: draft
---

# Brainstorm: Train/Exercise 통합 워크아웃 Row 리디자인

## Problem Statement

Train 탭의 Recent Workouts와 Exercise 탭의 운동 목록 사이에 **5가지 UI 괴리**가 존재하여 사용자 경험이 불일치:

1. **타이틀 불일치**: 수동 기록이 Train 탭에서는 영어 raw 문자열(`record.exerciseType`), Exercise 탭에서는 한국어 우선(`localizedType ?? type`)
2. **아이콘 불일치**: Train 탭은 legacy 문자열 매칭(항상 초록), Exercise 탭은 수동 기록에 아이콘 없음
3. **정렬 불일치**: Train 탭은 수동→HealthKit 분리 배치(날짜 무시), Exercise 탭은 날짜순 통합
4. **색상 불일치**: 수동 기록이 항상 초록 vs HealthKit은 카테고리별 색상
5. **상세 화면 불일치**: ExerciseSessionDetailView는 아이콘/헤더 없음, HealthKitWorkoutDetailView는 풍부한 헤더

## Target Users

- 앱의 모든 사용자 (Train 탭은 메인 대시보드이므로 모든 사용자가 매일 접함)

## Success Criteria

1. Train 탭과 Exercise 탭에서 **같은 운동이 같은 모양**으로 표시됨
2. Train 탭 대시보드는 **Quick Glance** 역할에 충실 (핵심 지표만 빠르게)
3. 수동 기록과 HealthKit 기록 구분 없이 **시간순 통합 정렬**
4. 공통 컴포넌트로 양쪽 재사용 → 미래 수정 시 한 곳만 변경
5. legacy `WorkoutSummary.iconName(for:)` 제거, `WorkoutActivityType` 기반 통합

## Current Architecture

### 현재 Row 컴포넌트 (분리됨)

```
ExerciseListSection.swift (Train 탭)
├── setRecordRow(_:)      → 수동 기록 전용, InlineCard 래핑
└── workoutRow(_:)        → HealthKit 전용, InlineCard 래핑

ExerciseView.swift (Exercise 탭)
└── ExerciseRowView       → 통합 row, plain List row
```

### 현재 아이콘 시스템 (이중화)

| 시스템 | 사용처 | 커버리지 |
|--------|--------|---------|
| `WorkoutActivityType.iconName` (enum 기반) | HealthKit rows | 70+ 운동 타입 |
| `WorkoutSummary.iconName(for:)` (string 기반) | Train 탭 수동 rows | ~15 타입만 |

### 현재 디자인 토큰 사용

| 항목 | Train 탭 | Exercise 탭 |
|------|---------|------------|
| 컨테이너 | `InlineCard` | plain `List` row |
| 아이콘 프레임 | `28pt` | `32pt` |
| 타이틀 폰트 | `.subheadline .medium` | `.headline` |
| 날짜 형식 | weekday + hour:minute | date only |
| spacing | DS 토큰 일관 | 하드코딩 4/6 혼용 |

### 상세 화면 비교

| 항목 | ExerciseSessionDetailView (수동) | HealthKitWorkoutDetailView (HK) |
|------|--------------------------------|-------------------------------|
| 헤더 아이콘 | 없음 | `.title` 크기, 카테고리 색상 |
| 제목 | `record.exerciseType` (raw) | `displayName` (한국어) |
| stat pills | 없음 | 시간/kcal/km 3개 |
| 통계 그리드 | 없음 | LazyVGrid 2열 |

## Proposed Approach

### Phase 1: 공통 데이터 모델 확인

수동 기록(`ExerciseRecord`)에서 `WorkoutActivityType`을 도출할 수 있는지 확인:
- `exerciseDefinitionID` → exercise library → `WorkoutActivityType` 매핑 가능 여부
- 매핑 불가 시 `ExerciseRecord`에 `activityType` 프로퍼티 추가 고려

### Phase 2: 공통 `UnifiedWorkoutRow` 컴포넌트

```swift
// Presentation/Shared/Components/UnifiedWorkoutRow.swift
struct UnifiedWorkoutRow: View {
    let item: WorkoutRowItem  // 공통 프로토콜 또는 struct
    let style: RowStyle       // .compact (Train) | .full (Exercise)
}
```

**`WorkoutRowItem` 프로토콜/struct:**
```
- activityType: WorkoutActivityType  // 아이콘 + 색상 소스
- displayName: String                // 한국어 우선 타이틀
- date: Date
- duration: TimeInterval
- calories: Double?
- heartRateAvg: Double?
- setSummary: String?                // 세트 기록 요약
- primaryMuscles: [MuscleGroup]?     // 근육 그룹 뱃지
- source: WorkoutSource              // .manual | .healthKit
- isPersonalRecord: Bool
- milestone: MilestoneDistance?
```

**Style variants:**

| `.compact` (Train 대시보드) | `.full` (Exercise 탭) |
|-----------------------------|----------------------|
| InlineCard 래핑 | plain List row |
| 아이콘 28pt | 아이콘 32pt |
| 날짜: weekday + time | 날짜: date |
| 핵심 지표만 (duration, kcal) | 확장 지표 (HR, pace, elevation) |
| 근육 뱃지 표시 | set summary 표시 |

### Phase 3: 정렬 통합

Train 탭의 `ExerciseListSection`에서:
- 수동/HealthKit 분리 렌더링 → **통합 배열 + 날짜순 정렬**로 변경
- `limit` 파라미터 유지 (대시보드는 최근 5개만)

### Phase 4: 상세 화면 헤더 통합

`ExerciseSessionDetailView`에도 `HealthKitWorkoutDetailView`와 유사한 헤더 추가:
- 운동 아이콘 + 카테고리 색상
- 한국어 displayName
- stat pills (시간, kcal)

### Phase 5: Legacy 제거

- `WorkoutSummary.iconName(for:)` 삭제
- 모든 참조를 `WorkoutActivityType.iconName`으로 교체

## Constraints

### 기술적 제약
- `ExerciseRecord`의 `exerciseType`은 raw string — `WorkoutActivityType` 매핑 레이어 필요
- SwiftData 스키마 변경 시 CloudKit 호환성 테스트 필수 (2회 실행)
- `ExerciseListItem`이 이미 통합 모델 역할을 하고 있음 — 확장 가능

### 범위 제약
- Train 탭의 다른 섹션(WeeklyProgress, MuscleRecovery, TrainingVolume)은 건드리지 않음
- Watch 화면은 이 scope에 포함하지 않음

## Edge Cases

1. **매핑 불가 운동**: `exerciseType`이 어떤 `WorkoutActivityType`에도 매핑되지 않을 때 → fallback: `.other` + `"figure.mixed.cardio"` 아이콘
2. **데이터 없음**: 최근 운동이 0건일 때 → 기존 empty state 유지
3. **HealthKit 권한 거부**: HealthKit 데이터 없이 수동 기록만 → 통합 Row가 수동 기록을 올바르게 표시
4. **오래된 데이터**: 30일 이상 운동 없을 때 → Train 대시보드에서 "마지막 운동: N일 전" 표시 고려
5. **iPad multitasking**: sizeClass 전환 시 Row 레이아웃 안정성 (기존 InlineCard의 adaptive 활용)

## Scope

### MVP (Must-have)
- [ ] 공통 `UnifiedWorkoutRow` 컴포넌트 생성
- [ ] Train 탭, Exercise 탭 양쪽에서 사용
- [ ] 수동 기록에 카테고리 아이콘+색상 적용
- [ ] 타이틀 한국어 `localizedType` 통일
- [ ] Train 탭 날짜순 통합 정렬
- [ ] legacy `WorkoutSummary.iconName(for:)` 제거
- [ ] ExerciseSessionDetailView 헤더 개선 (아이콘, 한국어 제목)

### Nice-to-have (Future)
- [ ] ExerciseSessionDetailView에 stat pills 추가
- [ ] ExerciseSessionDetailView에 통계 그리드 추가
- [ ] 공통 WorkoutDetailHeader 컴포넌트 추출
- [ ] "마지막 운동: N일 전" 표시 (30일+ 미운동 시)
- [ ] Train 대시보드에 "오늘 운동" 필터 옵션

## Open Questions

1. **`ExerciseRecord` → `WorkoutActivityType` 매핑**: `exerciseDefinitionID`로 exercise library를 조회하면 카테고리를 알 수 있는가? 아니면 별도 매핑 테이블이 필요한가?
2. **Train 대시보드 Row에 근육 뱃지 유지?**: Quick Glance 역할이면 근육 뱃지를 빼고 더 compact하게 만들 수도 있음
3. **ExerciseListItem 재사용 vs 새 프로토콜**: 이미 `ExerciseListItem`이 통합 모델 역할 → 이것을 공통 Row의 데이터 소스로 사용할지, 별도 `WorkoutRowItem`을 만들지

## Next Steps

- [ ] `/plan unified-workout-row` 으로 구현 계획 생성
