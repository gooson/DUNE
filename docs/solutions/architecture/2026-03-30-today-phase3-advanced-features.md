---
tags: [dashboard, today, phase3, time-aware, stress-score, daily-digest, composite-score, notification]
date: 2026-03-30
category: architecture
status: implemented
---

# Today Tab Phase 3: Time-Aware Dashboard + Cumulative Stress + Daily Digest

## Problem

Phase 2에서 5개 기능(Adaptive Hero, Quick Actions, Progress Ring, Intelligence Card, Yesterday Recap)을 추가했지만, 대시보드가 시간대에 관계없이 동일한 섹션 순서를 보여주고, 장기 스트레스 추세와 하루 마무리 요약이 없었다.

## Solution

### 1. Time-Aware Dashboard (DashboardTimeBand)
- `DashboardTimeBand` enum: morning(06-10), daytime(10-17), evening(17-22), night(22-06)
- `currentTimeBand`은 **stored property**로 `loadData()` 시점에 pre-compute (Calendar 연산을 body에서 반복 금지)
- 시간대별 섹션 가시성: computed property `shouldShowQuickActions`, `shouldShowProgressRings`, `shouldShowTodaysBrief`, `shouldShowExerciseIntelligence`, `shouldShowDailyDigest`
- 밤에는 Quick Actions/Progress Rings 숨김, 저녁/밤에는 Daily Digest 표시

### 2. Cumulative Stress Score
- `CumulativeStressScore` 모델: 0-100 점수, 4단계 레벨(low/moderate/elevated/high), 기여 요인, 추세
- `CalculateCumulativeStressUseCase`: CV 기반 HRV 변동성(0.40) + 수면 비일관성(0.35) + 활동 과부하(0.25) 가중 합산
- 최소 7일 데이터 요구 (미만이면 nil → 카드 숨김)
- 누락 컴포넌트는 WellnessScore 패턴과 동일하게 가중치 재분배
- `CumulativeStressCard`: 링 게이지 + 레벨 + 트렌드 + 상위 2개 기여 요인

### 3. AI Daily Digest
- `DailyDigest` 모델: 요약 텍스트 + 메트릭 스냅샷
- `GenerateDailyDigestUseCase`: 템플릿 기반 요약 생성 (Foundation Models 통합은 향후)
- 17시 이후에만 생성, 저녁/밤 시간대에만 카드 표시
- `HealthInsight.InsightType.dailyDigest` 추가 (푸시 알림 인프라 확보)

## Key Decisions

1. **`currentTimeBand`을 stored property로**: 리뷰에서 `sectionVisibilityHash`에 computed 값 포함 시 무한 re-render 위험 지적 → pre-compute로 전환
2. **수면 일관성 데이터 프록시**: CalculateSleepRegularityUseCase를 직접 호출하지 않고 `SleepDeficitAnalysis.dailyDeficits`의 수면 시간 분산을 프록시로 사용. 정확한 취침/기상 시간 규칙성과는 다르지만, 추가 HK 쿼리 없이 근사 가능
3. **최소 3일 데이터 요구**: 수면 1-2일 데이터에서 분산=0 → "완벽한 규칙성" 오판 방지
4. **템플릿 기반 digest**: Foundation Models는 기기 지원이 제한적이므로 MVP는 템플릿. 향후 `FoundationModelReportFormatter` 패턴을 적용하여 AI 요약으로 확장 가능
5. **활동 부하 단순화**: 오늘 운동 데이터만으로 주간 부하를 외삽하므로 정확도 제한. 향후 WorkoutQueryService에서 7일/28일 실데이터를 직접 fetch하여 개선 필요

## Prevention

- `DashboardTimeBand`은 body에서 직접 계산하지 않고 `loadData()`에서 설정 (performance-patterns.md Calendar 규칙)
- 새 시간대 기반 가시성 추가 시 `sectionVisibilityHash`에 포함 필수
- 복합 점수 모델 추가 시 WellnessScore 패턴(가중치 재분배, Contribution 추적) 따를 것
- xcstrings에 interpolation 포함 문자열 등록 시 `%lld`, `%@` 등 format specifier 형식 확인 필요

## Lessons Learned

- InsightType enum에 새 case 추가 시 최소 4곳의 exhaustive switch를 업데이트해야 함 → 빌드 에러로 즉시 발견되지만 일괄 수정 필요
- DS.Color 토큰명 확인 후 사용: `DS.Color.warning` 없음 → `DS.Color.caution` 사용
- xcstrings에 interpolation 문자열은 Xcode가 자동 추출하므로 수동 등록보다 빌드 후 자동 감지가 효율적
