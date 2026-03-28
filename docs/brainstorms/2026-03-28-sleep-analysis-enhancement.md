---
tags: [sleep, healthkit, vitals, breathing-disturbances, waso, rem, correlation]
date: 2026-03-28
category: brainstorm
status: draft
---

# Brainstorm: 수면 분석 고도화 (0.7.0)

## Problem Statement

현재 DUNE의 수면 분석은 Sleep Stage 기반 점수 + 수면 부채 + 오늘밤 예측의 3축 구조이다.
그러나 Apple Watch가 이미 수집하는 **Breathing Disturbances, 야간 심박수, 호흡수, 손목 온도, SpO2** 등의
풍부한 야간 바이탈 데이터를 수면 분석에 활용하지 못하고 있다.

iOS 26.4에서 Apple Health가 Average Bedtime Highlight와 Vitals 통합 차트를 도입한 시점에서,
DUNE도 수면 분석을 포괄적으로 고도화하여 **단순 점수 → 다차원 수면 건강 인사이트**로 전환한다.

## Target Users

- Apple Watch 착용하고 수면 추적하는 사용자 (primary)
- 운동하는 사용자가 수면이 퍼포먼스에 미치는 영향을 이해하고 싶은 경우
- Apple Watch 없이 수동 수면 기록만 있는 사용자 (graceful degradation)

## Success Criteria

1. Sleep Score가 REM 비율과 WASO를 반영하여 더 정확한 수면 품질 평가 제공
2. Breathing Disturbances 추세를 30일 차트로 시각화
3. 수면 중 HR/호흡수/온도/SpO2를 수면 단계 타임라인에 오버레이
4. 운동 강도별 수면 품질 변화를 회고적으로 분석/시각화
5. Apple Watch 미착용 사용자에게 기능 제한을 명확히 안내

## Proposed Approach

### MVP 1: REM + WASO 반영 (기존 코드 수정)

**Sleep Score 재설계:**

| 컴포넌트 | 현재 | 변경 후 | 근거 |
|----------|------|---------|------|
| Duration | 40% | 30% | REM/WASO에 가중치 배분 |
| Deep Sleep | 30% | 20% | REM과 분리하여 각각 평가 |
| REM Sleep | - | 15% (new) | 기억 강화, 감정 조절에 필수 |
| Efficiency | 30% | 20% | WASO와 분리하여 세분화 |
| WASO | - | 15% (new) | 중간 각성이 수면 품질 핵심 지표 |

**WASO (Wake After Sleep Onset) 분석:**
- 수면 개시 후 5분 이상 지속되는 각성 구간 식별
- 메트릭: 각성 횟수, 총 WASO 시간, 최장 단일 각성
- 점수화: WASO 0-10분 → 만점, 10-30분 → 선형 감소, 30분+ → 최저

**REM 비율 점수화:**
- 이상 범위: 20-25% (수면의학 권장)
- 20% 중심으로 Deep Sleep과 동일한 페널티 곡선

**영향 파일:**
- `DUNE/Domain/UseCases/CalculateSleepScoreUseCase.swift` — 가중치 재설계
- `DUNE/Domain/Models/HealthMetric.swift` — `SleepStage` 활용 확장
- `DUNE/Presentation/Sleep/SleepViewModel.swift` — WASO 메트릭 노출
- 신규: `DUNE/Domain/UseCases/AnalyzeWASOUseCase.swift`
- 신규: `DUNE/Domain/Models/WakeAfterSleepOnset.swift`

### MVP 2: Breathing Disturbances 통합

**HealthKit 연동:**
- `HKQuantityType(.appleSleepingBreathingDisturbances)` 읽기 권한 추가
- 단위: count/hour (시간당 호흡 장애 횟수)
- Apple Watch Series 9+ 에서만 데이터 생성

**분류 기준 (Apple 기준):**
- Not Elevated: < 특정 임계값 (Apple 내부 기준)
- Elevated: 지속적으로 높은 수치 → 수면 무호흡 위험 시사

**UI 설계:**
- Sleep 섹션에 새 카드: "Breathing Disturbances"
- 30일 추세 차트 (bar chart, elevated 날 강조)
- Elevated 지속 시 코칭 인사이트: "수면 전문의 상담 권장"

**영향 파일:**
- `DUNE/Data/HealthKit/HealthKitManager.swift` — readTypes에 추가
- 신규: `DUNE/Data/HealthKit/BreathingDisturbanceQueryService.swift` (또는 VitalsQueryService 확장)
- 신규: `DUNE/Domain/Models/BreathingDisturbanceAnalysis.swift`
- 신규: `DUNE/Presentation/Sleep/Components/BreathingDisturbanceCard.swift`
- `DUNE/Domain/UseCases/CoachingEngine.swift` — elevated 시 인사이트 추가

### MVP 3: 수면-운동 상관분석

**데이터 쌍 구성:**
- 각 밤의 수면 데이터 ↔ 직전 낮의 운동 데이터 매칭
- 최소 14쌍 이상 시 분석 시작 (confidence 표시)

**분석 차원:**
1. **강도별 수면 품질**: rest / light / moderate / intense → 평균 sleep score
2. **운동 유형별**: strength / cardio / flexibility → 수면 영향 비교
3. **운동 시간대별**: 취침 전 N시간 → 수면 효율 영향
4. **트렌드**: 운동 강도와 수면 점수의 시계열 상관

**UI 설계:**
- Activity 탭 또는 Sleep 상세에 새 섹션
- Bar chart: 운동 강도별 평균 수면 점수
- 인사이트 카드: "중강도 운동 후 수면이 평균 12% 향상"
- 최적 운동 유형/시간 추천

**영향 파일:**
- 신규: `DUNE/Domain/UseCases/CorrelateSleepExerciseUseCase.swift`
- 신규: `DUNE/Domain/Models/SleepExerciseCorrelation.swift`
- 신규: `DUNE/Presentation/Sleep/Components/SleepExerciseCorrelationView.swift`
- `DUNE/Presentation/Sleep/SleepViewModel.swift` — 상관분석 데이터 로드

### MVP 4: 야간 바이탈 통합 대시보드

**데이터 수집 (수면 윈도우 기준):**
- HR samples: `HeartRateQueryService` — 수면 시작~종료 구간
- Respiratory Rate: `VitalsQueryService` — 야간 데이터
- Wrist Temperature: `VitalsQueryService` — `appleSleepingWristTemperature`
- SpO2: `VitalsQueryService` — `oxygenSaturation`

**데이터 정렬:**
- 수면 단계 타임라인과 시간축 통일
- 5분 단위 bucketing으로 차트 렌더링 최적화 (원본 ~480 HR 샘플 → ~96 buckets)

**UI 설계:**
- Sleep 상세 화면의 새 섹션: "Overnight Vitals"
- 주 차트: Sleep stage timeline (기존)
- 하위 오버레이 트랙 (선택적 표시):
  - HR 라인 차트 (min/avg/max 표시)
  - 호흡수 라인
  - 손목 온도 편차 (기준선 대비)
  - SpO2 (있으면)
- 요약 통계: 최저 HR, 평균 HR, 온도 편차, 호흡수 범위

**성능 고려:**
- 8시간 수면 × 1 sample/min = ~480 HR 샘플
- 5분 bucketing으로 ~96개 데이터 포인트로 축소
- `.clipped()` 필수 (swiftui-patterns.md)
- LazyVStack 내 chart는 격리 (performance-patterns.md)

**영향 파일:**
- 신규: `DUNE/Domain/UseCases/AggregateNocturnalVitalsUseCase.swift`
- 신규: `DUNE/Domain/Models/NocturnalVitalsSnapshot.swift`
- 신규: `DUNE/Presentation/Sleep/Components/NocturnalVitalsChartView.swift`
- `DUNE/Presentation/Sleep/SleepViewModel.swift` — 야간 바이탈 로드
- `DUNE/Data/HealthKit/HeartRateQueryService.swift` — 수면 윈도우 전용 쿼리 (있으면 재활용)

## Constraints

- **기술 제약 없음**: 기존 Sleep Score 변경, 새 기능 추가 모두 자유
- **Apple Watch 의존**: Breathing Disturbances, 상세 수면 단계, 야간 바이탈은 Watch 필수
- **HealthKit 권한**: 새 데이터 타입 추가 시 권한 요청 업데이트 필요
- **데이터 축적 기간**: 상관분석은 14일+, Breathing Disturbances는 30일+ 필요

## Edge Cases

1. **Apple Watch 미착용**: Watch-only 데이터 없으면 해당 섹션 숨김 + "Apple Watch로 더 상세한 분석" 안내
2. **짧은 수면 (<3h)**: WASO 분석 부정확 가능 → Score에는 반영하되 "짧은 수면" 경고 표시
3. **운동 없는 날**: 상관분석에서 "Rest day" 카테고리로 독립 집계
4. **Breathing Disturbances 데이터 부족 (<30일)**: "데이터 수집 중" 상태 표시, 추세 차트 미표시
5. **다중 소스 바이탈**: Watch 우선, 동일 시간대 타사 앱 데이터 dedup
6. **수면 중 Watch 탈착**: 부분 데이터만 존재할 수 있음 → 가용 데이터로 최선의 분석
7. **SpO2 미지원 기기**: Apple Watch SE 등 SpO2 미지원 시 해당 트랙만 숨김
8. **Breathing Disturbances 미지원 기기**: Series 9 미만에서 데이터 없음 → 해당 카드 숨김

## Scope

### MVP (Must-have) — 0.7.0

1. **REM + WASO 반영**: Sleep Score 5축 재설계, WASO 메트릭 표시
2. **Breathing Disturbances**: HealthKit 읽기, 30일 추세 카드, 코칭 연동
3. **수면-운동 상관분석**: 강도별 수면 품질 비교, 인사이트 카드
4. **야간 바이탈 대시보드**: 수면 단계 + HR/호흡수/온도/SpO2 오버레이

### Nice-to-have (Future)

5. **수면 환경 분석**: 외부 기온/습도와 수면 품질 상관 (#4)
6. **Sleep Regularity Index**: 취침+기상 양방향 일관성 학술 지표 (#6)
7. **낮잠 감지/분리**: 30분+ 낮잠 자동 식별, 별도 추적 (#9)
8. **수면 부채 회복 예측**: 현재 부채 기반 회복 소요일수 (#10)
9. **Apple Health 스타일 Vitals 통합 뷰**: HR/호흡수/온도/SpO2/수면을 하나의 차트에 (#Apple Health parity)
10. **Apple Sleep Score 비교**: watchOS 26 자체 점수와 DUNE 점수 나란히 표시 (API 공개 시)

## Open Questions

1. Sleep Score 가중치 변경 시 What's New 또는 변경 안내가 필요한가?
2. Breathing Disturbances의 "Elevated" 기준을 Apple 내부 기준 그대로 사용할지, 자체 정의할지?
3. 야간 바이탈 대시보드에서 SpO2를 별도 트랙으로 표시할지, HR과 동일 축에 배치할지?
4. 수면-운동 상관분석을 Sleep 탭에 배치할지, Activity 탭에 배치할지?

## Implementation Priority

```
Phase 1: REM + WASO 반영 (기존 코드 수정, 가장 빠름)
    ↓
Phase 2: Breathing Disturbances (새 쿼리 + 새 UI, 독립적)
    ↓
Phase 3: Sleep-Exercise Correlation (새 UseCase + 새 UI, 독립적)
    ↓
Phase 4: Nocturnal Vitals Dashboard (가장 복잡, 다중 데이터 소스 정렬)
```

## References

- [iOS 26.4 Sleep Highlight — 9to5Mac](https://9to5mac.com/2026/02/17/ios-26-4-adds-more-sleep-and-vitals-data-to-apple-health/)
- [iOS 26.4 Average Bedtime — MacRumors](https://www.macrumors.com/2026/02/17/ios-26-4-average-bedtime-vitals-blood-oxygen/)
- [Apple Watch Sleep Apnea — Apple Support](https://support.apple.com/en-us/120031)
- [HKQuantityType.appleSleepingBreathingDisturbances — Apple Developer](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingbreathingdisturbances)
- [HKQuantityType.appleSleepingWristTemperature — Apple Developer](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature)
- [Apple Watch Sleep Score — the5krunner](https://the5krunner.com/2025/10/06/how-apple-watchs-sleep-score-is-calculated-all-you-need-to-know-to-improve-sleep-health/)
- [HKCategoryValueSleepAnalysis — Apple Developer](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis)

## Next Steps

- [ ] `/plan 2026-03-28-sleep-analysis-enhancement` 으로 구현 계획 생성
- [ ] Phase별 TODO 생성
