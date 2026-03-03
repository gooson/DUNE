---
tags: [stair-climber, flights-climbed, healthkit, cardio, watch]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: Stair Climber 운동 강화 + 층수 추적

## Problem Statement

"천국의 계단" (Stair Climber 머신) 운동이 앱에 타입으로는 존재하지만:
1. 한국어 별칭이 없어 검색이 어려움
2. 운동 중/후 **오른 층수(flights climbed)** 핵심 지표가 표시되지 않음
3. HealthKit `flightsClimbed` 데이터를 수집하지 않고 있음

사용자는 Stair Climber 운동 시 "몇 층 올랐는지"를 가장 중요하게 생각한다.

## Target Users

- 헬스장에서 StairMaster/StepMill 머신을 사용하는 사용자
- Apple Watch를 착용하고 운동하는 사용자

## Success Criteria

1. "천국의 계단" 검색으로 stairStepper 운동을 찾을 수 있다
2. Watch에서 Stair Climber 운동 중 실시간 층수가 표시된다
3. 운동 완료 후 요약에 오른 층수가 표시된다

## 현재 상태 분석

### 이미 구현됨
- `WorkoutActivityType.stairClimbing` / `.stairStepper` (cardio 카테고리)
- `HKWorkoutActivityType.stairClimbing` / `.stairs` 매핑
- `elevationAscended` 미터 단위 추출 (`HKMetadataKeyElevationAscended`)
- `highestElevation` Personal Record 추적
- Exercise Library alias 검색 시스템 (`ExerciseDefinition.aliases`)

### 미구현 (Gap)
- `HKQuantityType.flightsClimbed` 쿼리 없음
- Watch 라이브 카디오 메트릭에 층수/고도 미표시
- 카디오 세션 요약에 층수 미표시
- "천국의 계단" 검색 alias 미등록

## Proposed Approach

### 1단계: Alias 추가
- Exercise Library JSON에 `stairStepper` → aliases: `["천국의 계단", "스텝밀", "스텝퍼"]`
- `stairClimbing` → aliases: `["계단 오르기", "계단 운동"]`

### 2단계: HealthKit flightsClimbed 수집
- `WorkoutManager`의 `HKLiveWorkoutBuilder` 수집 quantity type에 `.flightsClimbed` 추가
- Watch 카디오 세션에서 실시간 층수 표시 (`CardioMetricsView`)
- `WorkoutSummary`에 `flightsClimbed: Double?` 필드 추가

### 3단계: UI 표시
- Watch `CardioMetricsView`: stair 타입일 때 distance 대신 floors 표시
- `CardioSessionSummaryView`: 층수 + 고도 표시
- iOS `HealthKitWorkoutDetailView`: 이미 elevation 표시 중 → floors 추가

## Constraints

- **Apple Watch 기압계 의존**: 실내에서도 기압 변화로 층수 측정 가능하나, Stair Climber 머신에서의 정확도는 Apple 센서 한계에 의존
- **1 flight ≈ 3m**: Apple 표준. 머신의 "층수" 표시와 다를 수 있음
- **Indoor 모드**: Stair Climber는 대부분 실내 → GPS 불필요, 기압계만 사용

## Edge Cases

- **flightsClimbed가 0인 경우**: 기압계 미작동 또는 평지 운동 → "층수 데이터 없음" 처리
- **기존 운동 기록에 flights 없음**: 과거 데이터는 elevation만 존재 → nil 허용
- **머신 표시 vs Watch 측정 차이**: 사용자 혼란 가능 → 앱에서 "Apple Watch 기준" 명시 고려
- **stairClimbing vs stairStepper 구분**: 둘 다 층수 표시 적용 (머신/실제 계단 무관)

## Scope

### MVP (Must-have)
- [ ] Exercise Library alias 추가 ("천국의 계단", "스텝밀", "계단 오르기" 등)
- [ ] `HKQuantityType.flightsClimbed` Watch 라이브 수집
- [ ] Watch 카디오 메트릭에 층수 표시 (stair 타입 한정)
- [ ] 카디오 세션 요약에 층수 표시
- [ ] `WorkoutSummary`에 `flightsClimbed` 필드 추가

### Nice-to-have (Future)
- [ ] 층수 기반 Personal Record (최다 층수/세션)
- [ ] 주간/월간 층수 통계 (Dashboard 위젯)
- [ ] 층수 목표 설정
- [ ] 머신 보정 옵션 (머신 표시 층수 수동 입력)

## 영향 파일 (예상)

| 파일 | 변경 내용 |
|------|----------|
| `ExerciseLibrary.json` (또는 해당 데이터 소스) | alias 추가 |
| `WorkoutManager.swift` | flightsClimbed quantity type 추가 |
| `CardioMetricsView.swift` | 층수 표시 UI 추가 |
| `CardioSessionSummaryView.swift` | 요약에 층수 추가 |
| `WorkoutSummary` (HealthMetric.swift) | flightsClimbed 필드 |
| `WorkoutQueryService.swift` | flightsClimbed 추출 로직 |
| `Localizable.xcstrings` (iOS + Watch) | 번역 키 추가 |

## Open Questions

1. ~~stairClimbing과 stairStepper 모두 층수를 표시할지, stairStepper만 표시할지~~ → 둘 다 표시
2. 층수 표시 단위: "15 floors" vs "15층" → locale 처리 필요

## Next Steps

- [ ] `/plan stair-climber-flights-tracking` 으로 구현 계획 생성
