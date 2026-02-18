---
tags: [training-volume, analytics, charts, apple-fitness, exercise-detail]
date: 2026-02-19
category: brainstorm
status: draft
---

# Brainstorm: 훈련량 분석 시스템 고도화

## Problem Statement

현재 Train 대시보드는 주간 운동 시간/걸음수, Training Load 차트, 최근 운동 목록 등 기본 정보를 제공하지만, **운동 종류별 세분화된 훈련량 분석**이 부재하다. 사용자가 "이번 달 달리기를 얼마나 했는지", "벤치프레스 볼륨이 지난달 대비 얼마나 늘었는지"를 한눈에 파악할 수 없다.

Apple Fitness 앱 수준의 **종합 훈련량 분석 시스템**을 구축하여, 개별 운동 종류별 트렌드와 기간별 비교를 제공한다.

## Target Users

- 주 3-5회 운동하는 중급자 ~ 상급자
- 다양한 운동을 병행하는 사용자 (근력 + 유산소 + 유연성)
- 훈련 볼륨 추적과 진보를 시각적으로 확인하고 싶은 사용자

## Success Criteria

1. Train 대시보드에서 2탭 이내로 운동 종류별 훈련량 확인 가능
2. 주/월 비교로 훈련 추세가 즉시 파악 가능
3. Apple Fitness 수준의 시각적 완성도 (링, 차트, 트렌드)
4. HealthKit 운동 + 수동 기록 모두 통합 분석

## Design Reference: Apple Fitness

### 핵심 참고 요소

1. **Activity Rings 스타일 요약**: 월간 운동 목표 달성률을 링 형태로 시각화
2. **운동 종류별 비중 차트**: 파이차트 또는 수평 막대로 종류별 시간/칼로리 비중
3. **기간별 트렌드 비교**: 이번 주 vs 지난 주, 이번 달 vs 지난 달
4. **개별 운동 드릴다운**: 특정 운동 종류 탭 → 해당 운동만의 상세 통계

## Proposed Architecture

### 대시보드 통합: 훈련량 관련 섹션 → 단일 카드

현재 ActivityView의 섹션 구조:

```
현재 (Before)                          변경 후 (After)
─────────────                         ─────────────
1. AI Workout Suggestion              1. AI Workout Suggestion
2. Weekly Summary Hero Chart  ─┐
3. Muscle Activity Summary    ─┼──→   2. 훈련량 분석 통합 카드
4. Training Load (28일)       ─┤         (요약 + 탭하면 상세 진입)
5. Today's Metrics            ─┘
6. Recent Workouts                    3. Recent Workouts
```

**통합 카드 구성**:
- Activity Ring (오늘/이번주 운동 달성률)
- Today 핵심 지표 2-3개 (운동 시간, 걸음수, 칼로리)
- 주간 미니 바 차트 (7일, 종류별 색상 구분)
- "상세 분석 보기" 진입점 → `TrainingVolumeDetailView`

기존 4개 섹션이 차지하던 수직 공간을 압축하고, 상세 정보는 drill-down으로 이동.

### 화면 구조

```
Train Dashboard
└── 훈련량 분석 통합 카드 (탭) → TrainingVolumeDetailView

TrainingVolumeDetailView (종합 훈련량 분석)
├── Period Picker: 주 / 월 / 3개월
├── Summary Section
│   ├── Activity Ring: 운동 일수 달성률 (목표 대비)
│   ├── 핵심 지표 카드: 총 시간 / 칼로리 / 세션 수
│   └── 기간 비교: 이전 기간 대비 증감 (↑12%, ↓5%)
├── 종류별 비중 차트 (도넛/파이)
│   └── 세그먼트: 시간 / 칼로리 / 세션 수 전환
├── 주간/월간 스택드 바 차트 (종류별 색상 구분)
├── Training Load 차트 (기존 28일 → 기간 연동)
├── Muscle Map (기존 근육 활동 요약 통합)
├── 운동 종류별 리스트
│   ├── 각 종류: 아이콘 + 이름 + 총 시간 + 세션 수 + 칼로리
│   └── 탭 → ExerciseTypeDetailView
└── Today's Metrics (기존 MetricCard 이동)

ExerciseTypeDetailView (개별 운동 종류 상세)
├── 운동 아이콘 + 이름 + 총합 통계
├── 기간별 추세 차트 (라인/바)
│   └── 메트릭 선택: 시간 / 칼로리 / 거리 / 볼륨(근력)
├── 기간 비교 (이번 주 vs 지난 주 등)
├── PR / 마일스톤 배지
└── 최근 세션 목록 (개별 세션 탭 → 기존 Detail View)
```

### 데이터 분류: 개별 운동 종류별

사용자 요구에 따라 **개별 운동 종류별** 분류:

**HealthKit 운동 (WorkoutSummary)**:
- `WorkoutActivityType` 기준 (달리기, 수영, 자전거, 요가 등)
- 100+ 타입이지만 사용자가 실제 한 운동만 표시

**수동 기록 (ExerciseRecord)**:
- `exerciseType` (벤치프레스, 스쿼트, 데드리프트 등)
- `ExerciseDefinition`의 이름 기준

**통합 표시 전략**:
- HealthKit 운동: `WorkoutActivityType.displayName` 기준 그룹핑
- 수동 근력 운동: 개별 exerciseType 기준 그룹핑
- 상위 레벨에서는 카테고리(근력/유산소/...) 그룹도 접을 수 있게

### 메트릭 정의

| 운동 종류 | 주요 볼륨 메트릭 | 보조 메트릭 |
|-----------|-----------------|------------|
| 유산소 (달리기, 자전거, 수영) | 총 거리 (km) | 총 시간, 평균 페이스, 칼로리 |
| 근력 (벤치프레스, 스쿼트 등) | 총 볼륨 (kg × reps) | 세트 수, 최대 중량, 1RM 추세 |
| 기타 (요가, HIIT 등) | 총 시간 | 세션 수, 칼로리 |

## Constraints

### 기술적

- HealthKit 데이터는 쿼리 시간이 필요 → 캐싱/프리로딩 전략 필수
- 장기간(6개월+) 데이터 집계는 메모리/성능 고려
- HealthKit + SwiftData 양쪽 데이터 통합 집계 필요
- 기존 `ActivityView` / `ActivityViewModel`에 진입점 추가

### UX

- 데이터가 없는 초기 사용자를 위한 빈 상태 디자인
- 기간 전환 시 부드러운 애니메이션 (Correction Log #29: `.id()` + `.transition(.opacity)`)
- 차트 선택 시 레이아웃 시프트 방지 (Correction Log #28: `.overlay`)

## Edge Cases

1. **데이터 없음**: 선택 기간에 운동 기록이 0건 → "이 기간에 기록된 운동이 없습니다" + 빈 상태 일러스트
2. **HealthKit 권한 거부**: 수동 기록만으로 분석 → 부분 데이터 안내 배너
3. **운동 종류가 매우 많음**: 20+ 종류 시 → 상위 N개 표시 + "더 보기" 접기
4. **기간 경계**: 1월 1주차가 이전 년도와 겹칠 때 → ISO week 기준 처리
5. **단위 혼재**: km/miles, kg/lbs → 사용자 설정 기반 (현재 미구현이면 metric 기본)
6. **중복 데이터**: HealthKit + 수동 기록 중복 → 기존 Dedup 로직 활용

## Scope

### MVP (Must-have)

**대시보드 통합**:
- [ ] 기존 4개 섹션 (WeeklySummary, MuscleMap, TrainingLoad, Today) → 훈련량 통합 카드로 교체
- [ ] 통합 카드: Activity Ring + Today 핵심 지표 + 주간 미니 바 차트
- [ ] 통합 카드 탭 → `TrainingVolumeDetailView` 진입

**TrainingVolumeDetailView (종합 상세)**:
- [ ] 기간 선택 (주/월/3개월)
- [ ] Activity Ring (운동 일수 달성률)
- [ ] 운동 종류별 비중 차트 (도넛 차트, 시간/칼로리/세션 수 전환)
- [ ] 기간 비교 (이번 기간 vs 이전 기간, 증감 표시)
- [ ] 주간/월간 스택드 바 차트 (종류별 색상 구분)
- [ ] Training Load 차트 통합 (기존 28일 → 기간 연동)
- [ ] Muscle Map 통합 (기존 근육 활동 요약 이동)
- [ ] Today's Metrics 통합 (기존 MetricCard 이동)
- [ ] 운동 종류별 리스트 (아이콘 + 시간 + 세션 수 + 칼로리)

**ExerciseTypeDetailView (개별 운동 상세)**:
- [ ] 개별 운동 추세 차트 (시간/칼로리/거리/볼륨)
- [ ] 기간별 비교 + PR/마일스톤 배지
- [ ] 최근 세션 목록

**데이터 레이어**:
- [ ] HealthKit + 수동 기록 통합 집계 서비스 (`TrainingVolumeAnalysisService`)

### Nice-to-have (Future)

- [ ] 운동 목표 설정 및 추적 (주 N회, 월 M분 등)
- [ ] 6개월 / 1년 장기 트렌드
- [ ] PDF/이미지 내보내기
- [ ] 근력 운동 볼륨 추세 (총 kg × reps 그래프)
- [ ] 개인 기록(PR) 타임라인
- [ ] 운동 패턴 인사이트 ("화요일에 가장 많이 운동합니다")
- [ ] 위젯 지원

## Open Questions

1. **운동 일수 목표 기본값**: 주 몇 회를 기본 목표로 설정할 것인가? (3회? 사용자 설정?)
2. **통합 볼륨 단위**: 근력(kg×reps) + 유산소(km) + 일반(분)을 하나의 지표로 통합할 것인가, 아니면 종류별로 다른 메트릭을 표시할 것인가?
3. **캐싱 전략**: HealthKit 장기 데이터 집계 결과를 SwiftData에 캐싱할 것인가? (성능 vs 복잡도)
4. ~~**Training Load 상세와 훈련량 분석의 관계**: 별도 화면 2개 vs 하나의 통합 화면?~~ → 통합 화면으로 결정

## New Files (예상)

```
Presentation/Activity/
├── TrainingVolume/
│   ├── TrainingVolumeDetailView.swift
│   ├── TrainingVolumeViewModel.swift
│   ├── ExerciseTypeDetailView.swift
│   ├── ExerciseTypeDetailViewModel.swift
│   └── Components/
│       ├── VolumeDonutChartView.swift
│       ├── ActivityRingView.swift
│       ├── PeriodComparisonView.swift
│       ├── StackedBarChartView.swift
│       ├── ExerciseTypeSummaryRow.swift
│       └── VolumeMetricCardView.swift
├── TrainingLoad/
│   ├── TrainingLoadDetailView.swift
│   └── TrainingLoadDetailViewModel.swift

Domain/UseCases/
├── TrainingVolumeAnalysisService.swift  (집계 로직)

Data/HealthKit/
├── WorkoutAggregationService.swift  (HealthKit 기간별 집계)
```

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
- [ ] Apple Fitness 앱 스크린샷 참고하여 UI 와이어프레임 확정
- [ ] 데이터 집계 성능 프로토타입 (HealthKit 3개월 쿼리 시간 측정)
