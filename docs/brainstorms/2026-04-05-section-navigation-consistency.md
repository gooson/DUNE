---
tags: [ux, navigation, consistency, section-group, detail-view]
date: 2026-04-05
category: brainstorm
status: draft
---

# Brainstorm: Section Navigation UX Consistency

## Problem Statement

탭 섹션 UI에서 상세 전환 UX가 일관성 없이 혼재되어 있음:
- **헤더 chevron**: Activity 탭 일부 섹션 (Injury Risk, Consistency, Exercise Mix 등)
- **하단 "View Details >"**: Dashboard (TodayBrief, RecoverySleep), Activity (MuscleMap)
- **하단 "View All >"**: Wellness (Body History, Injury History, Posture History)
- **카드 전체 탭 (암시적)**: 히어로 카드 (Condition, Readiness, Wellness), 메트릭 그리드
- **네비게이션 없음**: Training Volume Card, Habit Completion Chart 등

## Target Users

앱 전체 사용자. 상세 정보 진입 경로의 예측 가능성이 UX 품질의 핵심.

## Success Criteria

1. 모든 섹션에서 동일한 네비게이션 패턴(SectionGroup 헤더 chevron) 사용
2. 히어로 카드 포함, 예외 없는 통일
3. 상세 뷰가 없던 섹션에도 상세 뷰 추가
4. 기존 기능 동작에 regression 없음

## Proposed Approach

**통일 패턴: SectionGroup 헤더 chevron**
- 섹션 제목 오른쪽에 `chevron.right` 아이콘
- 카드/섹션 전체도 탭 가능 (NavigationLink로 래핑)
- 하단 "View Details" / "View All" 텍스트 버튼 제거

## Current State Audit

### Dashboard 탭

| 섹션 | 현재 패턴 | 상세 뷰 존재 | 변경 필요 |
|------|----------|-------------|----------|
| Condition Hero | 카드 전체 탭 | O (ConditionScoreDetailView) | 헤더 chevron 추가 |
| Cumulative Stress Card | 카드 전체 탭 | O (CumulativeStressDetailView) | 헤더 chevron 추가 |
| Today Brief Card - Weather | 버튼 탭 | O (WeatherDetailView) | 헤더 chevron으로 변경 |
| Today Brief Card - Briefing | 하단 "View Details" | O (MorningBriefingView) | 헤더 chevron으로 변경 |
| Recovery & Sleep Card | 하단 "Sleep Details" | O (sleep 관련 뷰) | 헤더 chevron으로 변경 |
| Health Metrics Grid | 개별 카드 탭 | O (MetricDetailView) | 개별 메트릭이므로 현행 유지 가능 |
| Daily Digest Card | 카드 전체 탭 | O | 헤더 chevron 추가 |
| Workout Recommendation | 카드 전체 탭 | O | 헤더 chevron 추가 |
| Weather Card | 카드 탭 | O (WeatherDetailView) | 헤더 chevron 추가 |
| Template Nudge Card | 카드 탭 | O (sheet) | sheet이므로 예외 가능 |
| Coaching Card | 카드 탭 | ? | 확인 필요 |
| Smart Insights | 개별 카드 탭 | O (각 insight) | 개별이므로 현행 유지 가능 |

### Activity 탭

| 섹션 | 현재 패턴 | 상세 뷰 존재 | 변경 필요 |
|------|----------|-------------|----------|
| Training Readiness Hero | 카드 전체 탭 | O (TrainingReadinessDetailView) | 헤더 chevron 추가 |
| Injury Risk Card | 헤더 chevron | O (InjuryRiskDetailView) | 현행 유지 (기준 패턴) |
| Weekly Report Card | 헤더 chevron | O (WorkoutReportDetailView) | 현행 유지 |
| Personal Records Section | 헤더 chevron + sparkline 탭 | O (PersonalRecordsDetailView) | 현행 유지 |
| Consistency Card | 헤더 chevron | O (ConsistencyDetailView) | 현행 유지 |
| Exercise Mix Section | 헤더 chevron | O (ExerciseMixDetailView) | 현행 유지 |
| Suggested Workout | 카드 전체 탭 | O (운동 시작) | 액션이므로 예외 |
| Muscle Map Section | 하단 "View Details" | O (MuscleMapDetailView) | 헤더 chevron으로 변경 |
| Weekly Stats Section | 카드 전체 탭 | O (WeeklyStatsDetailView) | 헤더 chevron 추가 |
| Training Volume Card | 네비게이션 없음 | O (TrainingVolumeDetailView) | 헤더 chevron 추가 |
| Recent Workouts | 개별 row 탭 | O (ExerciseSessionDetailView) | 리스트이므로 현행 유지 |

### Wellness 탭

| 섹션 | 현재 패턴 | 상세 뷰 존재 | 변경 필요 |
|------|----------|-------------|----------|
| Wellness Hero Card | 카드 전체 탭 | O (WellnessScoreDetailView) | 헤더 chevron 추가 |
| Sleep Prediction Card | 카드 전체 탭 | O (SleepPredictionDetailView) | 헤더 chevron 추가 |
| Physical Metrics Grid | 개별 카드 탭 | O (MetricDetailView) | 개별이므로 현행 유지 |
| Active Indicators Grid | 개별 카드 탭 | O (MetricDetailView) | 개별이므로 현행 유지 |
| Body History | 하단 "View All" | O (BodyHistoryDetailView) | 헤더 chevron으로 변경 |
| Injury History | 하단 "View All" | O (InjuryHistoryView) | 헤더 chevron으로 변경 |
| Posture History | 하단 "View All" | O (PostureHistoryView) | 헤더 chevron으로 변경 |
| Watch Posture Summary | 카드 표시 | ? | 확인 필요 |

### Sleep (Dashboard 내 또는 독립)

| 섹션 | 현재 패턴 | 상세 뷰 존재 | 변경 필요 |
|------|----------|-------------|----------|
| Sleep Deficit Gauge | 하단 버튼 | O (SleepDebtInfoSheet) | sheet이므로 확인 필요 |
| Sleep Regularity Card | ? | ? | 확인 필요 |
| Breathing Disturbance | ? | ? | 확인 필요 |
| Nap Detection Card | ? | ? | 확인 필요 |
| Sleep Environment Card | ? | ? | 확인 필요 |
| Vitals Timeline Card | ? | ? | 확인 필요 |

### Life 탭

| 섹션 | 현재 패턴 | 상세 뷰 존재 | 변경 필요 |
|------|----------|-------------|----------|
| Habit Heatmap | 탭 | O (HabitHeatmapDetailView) | 헤더 chevron 추가 |
| Weekly Report | 독립 버튼 "View Weekly Report" | O (WeeklyHabitReportView) | 헤더 chevron으로 변경 |
| Habit Completion Chart | 네비게이션 없음 | X | 상세 뷰 생성 필요 |
| Auto Workout Achievements | 카드 표시 | ? | 확인 필요 |

## Constraints

- **SectionGroup 컴포넌트**: 기존 `SectionGroup` 뷰가 있으면 활용, 없으면 생성 필요
- **히어로 카드**: 현재 `NavigationLink(value:)` 래핑 → SectionGroup 패턴 적용 시 구조 변경 필요
- **개별 아이템 리스트**: Recent Workouts, Metrics Grid 등은 개별 row 네비게이션이 자연스러우므로 예외 처리
- **Sheet 전환**: Template Nudge, Sleep Debt Info 등 sheet로 열리는 것은 push navigation과 다른 패턴이므로 별도 취급
- **상세 뷰 신규 생성**: Habit Completion Chart 등은 상세 뷰 자체를 만들어야 함

## Edge Cases

- 데이터 없는 상태에서 상세 뷰 진입 → Empty State 필요
- 히어로 카드에 chevron 추가 시 시각적 밸런스 (큰 카드 + 작은 chevron)
- iPad에서 SectionGroup 헤더 터치 영역 크기

## Scope

### MVP (Must-have)
- [ ] 기존 "하단 View Details/View All" → SectionGroup 헤더 chevron으로 변경
- [ ] 히어로 카드에 SectionGroup 헤더 chevron 패턴 적용
- [ ] Muscle Map Section 헤더 chevron 변경
- [ ] Weekly Stats Section 헤더 chevron 추가
- [ ] Training Volume Card에 상세 뷰 연결 (이미 뷰 존재)
- [ ] Life 탭 Weekly Report 헤더 chevron 변경
- [ ] Habit Heatmap 헤더 chevron 추가

### Nice-to-have (Future)
- [ ] Habit Completion Chart 상세 뷰 생성
- [ ] Sleep 섹션 카드들 네비게이션 일관성 검토
- [ ] SectionGroup 공통 컴포넌트에 네비게이션 패턴 내장
- [ ] 접근성: VoiceOver에서 "탭하여 상세 보기" 힌트 통일

## Open Questions

1. Health Metrics Grid / Smart Insights 같은 **개별 아이템 컬렉션**은 SectionGroup 헤더 chevron 대신 개별 row chevron을 유지하는 것이 맞는가?
2. Sheet로 열리는 항목(Template Nudge, RPE Help 등)도 chevron 표시를 할 것인가, 아니면 push navigation만 chevron을 사용할 것인가?
3. SectionGroup 컴포넌트가 이미 chevron 지원을 내장하고 있는가, 아니면 수정이 필요한가?

## Next Steps

- [ ] /plan 으로 구현 계획 생성
- [ ] SectionGroup 컴포넌트 현재 구현 확인
- [ ] 변경 대상 섹션 우선순위 결정 (탭별 순차 vs 패턴별 일괄)
