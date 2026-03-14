---
tags: [ui, hero-card, detail-view, chart, consistency, design-system]
date: 2026-03-14
category: brainstorm
status: draft
---

# Brainstorm: 히어로 카드 상세 화면 통일성 개선

## Problem Statement

3개 탭(Today, Activity, Wellness)의 점수형 히어로 카드 상세 화면이 각각 독립적으로 발전하면서 레이아웃 순서, 차트 타입, 섹션 구성, 기간 선택기, Summary Stats 유무 등이 불일치한다. Activity 탭의 비점수형 상세 화면도 공통 패턴 없이 개별 구현되어 있다.

사용자 관점에서 탭을 넘나들 때 "같은 앱인데 다른 앱 같은" 경험이 된다.

## Target Users

- DUNE 앱의 전체 사용자 (건강/피트니스 데이터를 다양한 탭에서 확인)
- 특히 Condition↔Wellness↔Readiness를 자주 비교하는 파워유저

## Success Criteria

1. 3개 점수형 상세 화면의 **섹션 순서가 동일**하다
2. 메인 트렌드 차트가 **DotLineChartView로 통일**된다
3. **모든 점수형 상세에 Period Picker**가 존재한다 (7D/30D/90D)
4. **서브스코어 차트**가 모든 점수형 상세에 존재한다
5. **Summary Stats** (Min/Max/Avg + 변화율)가 통일 포맷이다
6. **계산 방식 카드**가 통일 포맷이다
7. Activity 비점수형 상세도 공통 레이아웃 원칙을 따른다
8. Empty State가 공통 컴포넌트를 사용한다

## Current State Analysis

### 점수형 히어로 카드 상세 (3개)

#### 섹션 순서 비교

| 순서 | Condition (Today) | Training Readiness (Activity) | Wellness |
|------|-------------------|-------------------------------|----------|
| 1 | DetailScoreHero | DetailScoreHero (5 sub) | DetailScoreHero (3 sub) |
| 2 | InsightSection | Time-of-Day Card | Time-of-Day Card |
| 3 | ContributorsView | ReadinessTrendChart | SubScoreTrendChart ×3 |
| 4 | CalculationCard | SubScoreTrendChart ×3 | Component Weights |
| 5 | **Period Picker** | Component Weights | ContributorsCard |
| 6 | Chart Header | Calculation Method | CalculationCard ×2 |
| 7 | **DotLineChartView** | _(없음)_ | Explainer |
| 8 | Summary Stats | _(없음)_ | _(없음)_ |
| 9 | Highlights | _(없음)_ | _(없음)_ |
| 10 | Explainer | _(없음)_ | _(없음)_ |

#### 차트 타입 비교

| 요소 | Condition | Training Readiness | Wellness |
|------|-----------|-------------------|----------|
| 메인 차트 | DotLineChartView (스크롤, 선택, 트렌드라인) | ReadinessTrendChartView (14D 고정, 160px) | _(없음)_ |
| 서브스코어 | _(없음)_ | SubScoreTrendChartView ×3 (HRV→RHR→Sleep) | SubScoreTrendChartView ×3 (Sleep→HRV→RHR) |
| Period Picker | 7D/30D/90D | _(없음)_ | _(없음)_ |
| Summary Stats | Min/Max/Avg + 변화율 | _(없음)_ | _(없음)_ |
| Highlights | 최고/최저/트렌드 | _(없음)_ | _(없음)_ |
| Chart Header | Visible range + 트렌드 토글 | _(없음)_ | _(없음)_ |

#### 기타 불일치

- **서브스코어 순서**: Readiness(HRV→RHR→Sleep) vs Wellness(Sleep→HRV→RHR) — 통일 필요
- **차트 컨테이너**: Condition은 StandardCard, Readiness는 패딩만, SubScoreTrendChart는 자체 material
- **Empty State**: Condition은 in-chart 교체, Readiness는 전체 화면, Wellness는 없음
- **DetailScoreHero subScores**: Condition(0개), Readiness(5개), Wellness(3개)

### Activity 비점수형 상세 (6개)

| View | Period Picker | 차트 타입 | Calculation 설명 | Empty State |
|------|-------------|----------|-----------------|-------------|
| TrainingVolume | VolumePeriod 있음 | Donut + StackedBar + Load | 없음 | 없음 |
| MuscleMap | 없음 | 근육맵 (비차트) | 없음 | ContentUnavailable |
| WeeklyStats | StatsPeriod 있음 | DailyVolume + TypeBreakdown | 없음 | 커스텀 |
| Consistency | 없음 | 캘린더 그리드 | 없음 | 커스텀 |
| ExerciseMix | 없음 | Donut + Bar | 없음 | 커스텀 |
| InjuryRisk | 없음 | DetailScoreHero + 기여 바 | Factor contribution | 텍스트 |

### 히어로 카드 (탭 목록) 비교

| 요소 | ConditionHeroView | HeroScoreCard (Readiness/Wellness) |
|------|-------------------|------------------------------------|
| 컴포넌트 | 자체 구현 | 공유 HeroScoreCard |
| 링 크기 | 128/88pt | 140/100pt |
| Sub-score | 없음 (trendBadges) | 3 bars with labels |
| Sparkline | Hourly + 7d fallback | Hourly only |
| Spacing | 24/16pt | DS.Spacing.md |

## Proposed Approach

### Phase 1: 통일 레이아웃 정의 (Canonical Section Order)

점수형 상세 화면 공통 섹션 순서:

```
1. DetailScoreHero (sub-scores 포함)
2. InsightSection (상태별 가이드)
3. Time-of-Day Card (4 phase)
4. Period Picker (7D / 30D / 90D)
5. Chart Header (visible range + trend toggle)
6. Main Trend Chart (DotLineChartView)
7. Summary Stats (Min / Max / Avg + 변화율)
8. Highlights (최고 / 최저 / 트렌드)
9. Sub-Score Charts (서브스코어 트렌드 ×N)
10. Component Weights (가중치 분해)
11. Contributors Card (기여 요인)
12. Calculation Card (계산 방식 — 통일 포맷)
13. Explainer Section (상세 방법론)
```

### Phase 2: 차트 통일

- **메인 차트**: 3개 모두 DotLineChartView 사용
  - Readiness: ReadinessTrendChartView → DotLineChartView로 교체
  - Wellness: 메인 트렌드 차트 신규 추가
- **서브스코어**: 3개 모두 SubScoreTrendChartView 사용
  - Condition: HRV + RHR 서브스코어 차트 신규 추가
  - 순서 통일: HRV → RHR → Sleep (심박 관련 먼저)
- **Period Picker**: 3개 모두 7D/30D/90D
  - Readiness/Wellness: TimePeriod picker 신규 추가

### Phase 3: 공통 컴포넌트 추출

- `ScoreDetailTemplate` 또는 shared section builder 패턴
- 통일 CalculationCard 포맷 (현재 Condition/Body 별도)
- 통일 Empty State 컴포넌트
- 통일 Summary Stats 컴포넌트

### Phase 4: 히어로 카드 통일 (추가 조사 필요)

ConditionHeroView가 HeroScoreCard를 사용하지 않는 점 — 통합 가능 여부 검토

### Phase 5: Activity 비점수형 상세 레이아웃 원칙

비점수형이라도 공통 원칙 적용:
- Empty State: 공통 컴포넌트 사용
- Period Picker: 시계열 데이터가 있는 화면은 필수
- Section 구분: SectionGroup 사용 통일

## Constraints

- **기존 ViewModel 수정 필요**: Readiness/Wellness ViewModel에 period 지원, DotLineChartView용 데이터 변환 추가
- **데이터 가용성**: Readiness/Wellness의 장기 데이터(90일)가 이미 수집되고 있는지 확인 필요
- **Condition에 없는 섹션**: Time-of-Day, Sub-Score — Condition 도메인에 맞는 서브스코어 정의 필요 (HRV, RHR)
- **Wellness에 없는 섹션**: Main trend chart, Summary Stats, Highlights — ViewModel 확장 필요
- **차트 성능**: DotLineChartView가 90일 데이터에서 performant한지 검증 (현재 Condition에서만 사용)
- **iPad 레이아웃**: Condition은 iPad responsive (HStack 분기), 나머지는 미확인

## Edge Cases

- 데이터 3일 미만: 차트가 의미 없음 → 공통 empty state + 최소 데이터 기준
- 서브스코어 일부만 있는 경우: 예) Sleep 데이터 없이 HRV만 → 가용한 서브스코어만 표시
- Period 전환 시 데이터 로딩: 스켈레톤/placeholder + `.id(period)` + `.transition(.opacity)` 패턴 (Condition 기존 패턴)
- Readiness calibrating 상태: 차트에 calibrating 배지/설명 필요
- 90일 DotLineChartView 스크롤 성능: 포인트 수 제한 또는 downsampling

## Scope

### MVP (Must-have)
- [ ] 3개 점수형 상세 화면 섹션 순서 통일
- [ ] 메인 트렌드 차트 DotLineChartView 통일
- [ ] Period Picker 3개 화면 모두 추가
- [ ] Condition에 서브스코어 차트(HRV, RHR) 추가
- [ ] Summary Stats 3개 화면 통일 포맷
- [ ] 서브스코어 차트 순서 통일 (HRV → RHR → Sleep)
- [ ] Calculation Card 통일 포맷
- [ ] Empty State 공통 컴포넌트

### Nice-to-have (Future)
- [ ] 히어로 카드(탭 목록) 통일 (ConditionHeroView → HeroScoreCard 통합)
- [ ] Activity 비점수형 상세 레이아웃 원칙 적용
- [ ] Highlights 섹션 3개 화면 모두 추가
- [ ] Time-of-Day 카드 Condition에 추가
- [ ] InsightSection Readiness/Wellness에 추가
- [ ] iPad responsive 레이아웃 3개 화면 통일

## Open Questions

1. **Condition 서브스코어 정의**: HRV와 RHR 외에 추가 서브스코어가 필요한가?
2. **Wellness 메인 점수 트렌드**: 현재 메인 Wellness 점수의 일별 히스토리가 저장되고 있는가? (DotLineChartView 데이터 소스)
3. **Readiness 장기 데이터**: 14일 이상(30D/90D) 데이터가 현재 쿼리 가능한가?
4. **Calculation Card 통일 수준**: 현재 Condition은 Z-score/StdDev 파이프라인, Body는 delta/points 파이프라인 — 공통 포맷이 "라벨:값" 행 리스트면 충분한가?
5. **차트 인터랙션**: 서브스코어 차트에도 선택(selection) 제스처를 추가할 것인가, 메인 차트만 interactive?

## Affected Files (예상)

### 수정 대상
| 파일 | 변경 내용 |
|------|----------|
| `Presentation/Dashboard/ConditionScoreDetailView.swift` | 섹션 순서 재배치, 서브스코어 차트 추가 |
| `Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | DotLineChart 교체, Period Picker 추가, Summary Stats 추가 |
| `Presentation/Wellness/WellnessScoreDetailView.swift` | 메인 차트 추가, Period Picker 추가, Summary Stats 추가 |
| `Presentation/Activity/TrainingReadiness/Components/SubScoreTrendChartView.swift` | 순서 통일, 포맷 점검 |

### 신규 생성 가능
| 파일 | 내용 |
|------|------|
| `Presentation/Shared/Components/ScoreDetailSummaryStats.swift` | 통일 Summary Stats 컴포넌트 |
| `Presentation/Shared/Components/ScoreDetailEmptyState.swift` | 통일 Empty State |
| `Presentation/Shared/Components/UnifiedCalculationCard.swift` | 통일 Calculation Card |

### ViewModel 수정
| 파일 | 변경 내용 |
|------|----------|
| TrainingReadiness ViewModel | Period 지원, DotLineChart 데이터, Summary Stats 계산 |
| Wellness ViewModel | Period 지원, 메인 점수 트렌드 데이터, Summary Stats 계산 |
| Condition ViewModel | 서브스코어(HRV, RHR) 트렌드 데이터 |

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
- [ ] Open Questions 1~5 답변 확인
- [ ] Phase 순서 결정 (MVP 우선)
