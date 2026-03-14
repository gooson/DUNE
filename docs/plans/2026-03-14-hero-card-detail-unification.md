---
topic: hero-card-detail-unification
date: 2026-03-14
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-28-detail-score-hero-unification.md
  - architecture/2026-03-08-chart-scroll-unified-vitals.md
  - general/hero-ring-label-consistency.md
  - general/2026-02-26-chart-axis-contrast-and-shimmer-transition.md
related_brainstorms:
  - 2026-03-14-hero-card-detail-unification.md
---

# Implementation Plan: 히어로 카드 상세 화면 통일

## Context

3개 점수형 상세 화면(Condition, Training Readiness, Wellness)이 독립적으로 발전하면서 레이아웃 순서, 차트 타입, 기간 선택기, Summary Stats 유무 등이 심하게 불일치한다. 사용자가 탭을 넘나들 때 "같은 앱인데 다른 앱 같은" 경험이 된다.

### 현재 불일치 요약

| 요소 | Condition | Readiness | Wellness |
|------|-----------|-----------|----------|
| Period Picker | 7D/30D/90D ✅ | ❌ (14D 고정) | ❌ |
| Main Trend Chart | DotLineChartView ✅ | ReadinessTrendChartView | ❌ |
| Sub-score Charts | ❌ | ✅ HRV→RHR→Sleep | ✅ Sleep→HRV→RHR |
| Summary Stats | ✅ Min/Max/Avg + 변화율 | ❌ | ❌ |
| Highlights | ✅ | ❌ | ❌ |
| Time-of-Day Card | ❌ | ✅ | ✅ |
| Component Weights | ❌ | ✅ | ✅ |
| Chart Header | ✅ (range + trend) | ❌ | ❌ |
| Contributors | ✅ | ❌ | ✅ |
| Calculation Card | ✅ ConditionCalc | ✅ bullet 형식 | ✅ Condition+Body+bullet |
| Explainer | ✅ ConditionExplainer | ❌ (calc에 통합) | ✅ bullet |

### 데이터 가용성

- **Condition**: ConditionScoreDetailViewModel이 직접 HealthKit 쿼리 → 임의 기간 지원 ✅
- **Readiness**: ActivityViewModel이 14일 고정 데이터 pre-fetch → ViewModel에 전달. 확장 필요
- **Wellness**: WellnessViewModel이 고정 데이터 pre-fetch → View에 전달. 확장 필요

## Requirements

### Functional

1. 3개 점수형 상세 화면의 섹션 순서 통일
2. 메인 트렌드 차트를 DotLineChartView로 통일 (스크롤, 선택 제스처, 트렌드 라인)
3. 3개 화면 모두 Period Picker (7D/30D/90D) 지원
4. Condition에 서브스코어 차트 (HRV, RHR) 추가
5. 서브스코어 차트 순서 통일: HRV → RHR → Sleep
6. Summary Stats (Min/Max/Avg + 변화율) 3개 화면 통일
7. Highlights 섹션 3개 화면 통일
8. Calculation Card 표현 형식 통일
9. Time-of-Day Card를 Condition에도 추가
10. Empty State 공통 컴포넌트
11. 서브스코어 차트에도 selection 제스처 (이미 있음, 확인만)

### Non-functional

- 90일 DotLineChartView 스크롤 성능 유지 (기존 Condition에서 검증됨)
- 추가 HealthKit 쿼리 비용 최소화 (기존 fetch 패턴 재활용)
- iPad responsive 레이아웃 유지

## Approach

**Condition을 기준 템플릿으로 삼고, Readiness/Wellness를 맞춘다.**

Condition이 가장 완성도 높은 구현(Period Picker, DotLineChart, Summary Stats, Highlights, Chart Header)을 가지므로 이를 "golden template"으로 삼는다. Readiness/Wellness에 없는 섹션을 추가하고, Condition에 없는 섹션(Time-of-Day, Sub-scores, Component Weights)을 추가한다.

### Key Architecture Decision

Readiness/Wellness 상세 ViewModel을 **self-contained**로 변경:
- 현재: 부모 ViewModel(ActivityVM, WellnessVM)에서 pre-fetch한 고정 데이터를 받음
- 변경: Condition처럼 **자체 HealthKit 쿼리**로 선택된 기간의 데이터를 직접 로드
- Readiness: `buildReadinessTrend()` 로직을 extended period에 적용
- Wellness: 유사하게 daily wellness score를 extended period에 대해 계산

### Shared Components 추출

공통 섹션을 shared component로 추출하여 3개 화면에서 재사용:
- `ScoreDetailSummaryStats` — Min/Max/Avg + 변화율 (현재 Condition에만 있음)
- `ScoreDetailHighlights` — 최고/최저/트렌드 (현재 Condition에만 있음)
- `ScoreDetailChartHeader` — visible range + trend toggle (현재 Condition에만 있음)
- `ScoreDetailEmptyState` — 공통 empty state
- `ScoreCompositionCard` — 가중치 분해 (현재 Readiness/Wellness에 인라인)
- `CalculationMethodCard` — 통일 계산 방식 카드 (현재 3곳 각각 다름)

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| ScoreDetailTemplate View | 코드 최소화 | 3개 화면 차이점 많아 파라미터 폭발 | ❌ 거부 |
| 현재처럼 공유 컴포넌트만 | 유연, 화면별 커스터마이즈 용이 | 순서 통일은 수동 관리 | ✅ 채택 |
| Protocol-based builder | Type-safe | 과잉 설계 | ❌ 거부 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Dashboard/ConditionScoreDetailView.swift` | Modify | 섹션 순서 재배치, Time-of-Day/Sub-scores/Weights 추가 |
| `Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | Modify | HRV/RHR 서브스코어 트렌드 데이터 추가 |
| `Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | Modify | DotLineChart 교체, Period Picker/Summary/Highlights 추가, 섹션 순서 통일 |
| `Presentation/Activity/TrainingReadiness/TrainingReadinessDetailViewModel.swift` | Modify | Self-contained HealthKit 쿼리, Period 지원, Summary Stats, Highlights |
| `Presentation/Wellness/WellnessScoreDetailView.swift` | Modify | Main chart 추가, Period Picker/Summary/Highlights 추가, 섹션 순서 통일 |
| `Presentation/Wellness/WellnessScoreDetailViewModel.swift` | New | Self-contained HealthKit 쿼리, Period 지원, Main trend, Summary, Highlights |
| `Presentation/Shared/Components/ScoreDetailSummaryStats.swift` | New | 공통 Summary Stats 컴포넌트 |
| `Presentation/Shared/Components/ScoreDetailHighlights.swift` | New | 공통 Highlights 컴포넌트 |
| `Presentation/Shared/Components/ScoreDetailChartHeader.swift` | New | 공통 Chart Header 컴포넌트 |
| `Presentation/Shared/Components/ScoreDetailEmptyState.swift` | New | 공통 Empty State 컴포넌트 |
| `Presentation/Shared/Components/ScoreCompositionCard.swift` | New | 공통 가중치 분해 카드 |
| `Presentation/Shared/Components/CalculationMethodCard.swift` | New | 통일 계산 방식 카드 |
| `Presentation/Activity/TrainingReadiness/Components/ReadinessTrendChartView.swift` | Delete | DotLineChartView로 교체되어 불필요 |

## Implementation Steps

### Step 1: 공통 컴포넌트 추출

Condition에 이미 있는 섹션을 독립 컴포넌트로 추출.

- **Files**:
  - New: `ScoreDetailSummaryStats.swift`, `ScoreDetailHighlights.swift`, `ScoreDetailChartHeader.swift`, `ScoreDetailEmptyState.swift`, `ScoreCompositionCard.swift`, `CalculationMethodCard.swift`
  - Modify: `ConditionScoreDetailView.swift` (추출한 컴포넌트 사용으로 전환)
- **Changes**:
  - `ScoreDetailSummaryStats`: MetricSummary 기반 Min/Max/Avg + 변화율 배지
  - `ScoreDetailHighlights`: [Highlight] 기반 아이콘+라벨+값+날짜 리스트
  - `ScoreDetailChartHeader`: visibleRangeLabel + trend toggle 버튼
  - `ScoreDetailEmptyState`: 차트 영역 empty state (아이콘 + 메시지)
  - `ScoreCompositionCard`: [(label, weight, score, color)] 기반 가중치 바
  - `CalculationMethodCard`: icon + title + [bullet 문자열] 형식
- **Verification**: Condition 화면이 추출 전과 동일하게 렌더링

### Step 2: Condition에 누락 섹션 추가

- **Files**: `ConditionScoreDetailView.swift`, `ConditionScoreDetailViewModel.swift`
- **Changes**:
  - Time-of-Day Card 추가 (Condition에도 timeOfDayAdjustment 있음 → ConditionScore 확인 필요)
  - Sub-score Charts 추가 (HRV, RHR 트렌드) — ViewModel에 hrvTrend/rhrTrend 프로퍼티 추가
  - Component Weights 추가 (HRV, RHR 가중치 표시)
  - 섹션 순서를 통일 순서로 재배치
- **Verification**: Condition 상세에 모든 통일 섹션이 표시됨

### Step 3: Training Readiness ViewModel 자립화

- **Files**: `TrainingReadinessDetailViewModel.swift`
- **Changes**:
  - `selectedPeriod: TimePeriod` 프로퍼티 추가
  - HRVQuerying/SleepQuerying/RHRQuerying 의존성 주입
  - `loadData()` → HealthKit에서 직접 extended period 데이터 fetch
  - `buildReadinessTrend()` → extended period 적용
  - summaryStats, highlights, visibleRangeLabel, trendLineData, scrollDomain 추가
  - 기존 pre-fetch 인터페이스 제거 (readiness만 외부에서 받고 트렌드 데이터는 자체 fetch)
- **Verification**: Period 변경 시 데이터가 올바르게 로드됨

### Step 4: Training Readiness View 통일

- **Files**: `TrainingReadinessDetailView.swift`
- **Changes**:
  - ReadinessTrendChartView → DotLineChartView 교체
  - Period Picker 추가
  - Chart Header 추가
  - ScoreDetailSummaryStats 추가
  - ScoreDetailHighlights 추가
  - componentWeights → ScoreCompositionCard 교체
  - calculationMethodSection → CalculationMethodCard 교체
  - 섹션 순서를 통일 순서로 재배치
  - ReadinessTrendChartView 파일 삭제
- **Verification**: Readiness 상세가 Condition과 동일한 레이아웃 구조

### Step 5: Wellness ViewModel 생성

- **Files**: New `WellnessScoreDetailViewModel.swift`
- **Changes**:
  - ConditionScoreDetailViewModel 패턴 참조
  - `selectedPeriod: TimePeriod` 지원
  - HealthKit에서 직접 Sleep/HRV/RHR 데이터 fetch (extended period)
  - daily wellness score 계산 (WellnessScore의 가중 평균 로직 재활용)
  - chartData, summaryStats, highlights, scrollDomain 등 제공
- **Verification**: Period 변경 시 Wellness 트렌드 데이터 로드

### Step 6: Wellness View 통일

- **Files**: `WellnessScoreDetailView.swift`
- **Changes**:
  - WellnessScoreDetailViewModel 사용으로 전환
  - DotLineChartView 메인 차트 추가
  - Period Picker 추가
  - Chart Header 추가
  - ScoreDetailSummaryStats 추가
  - ScoreDetailHighlights 추가
  - 서브스코어 순서 HRV→RHR→Sleep으로 변경
  - componentWeights → ScoreCompositionCard 교체
  - explainerCard → CalculationMethodCard 교체
  - 섹션 순서를 통일 순서로 재배치
- **Verification**: Wellness 상세가 Condition/Readiness와 동일한 레이아웃 구조

### Step 7: 서브스코어 차트 순서 통일 + 정리

- **Files**: All 3 detail views
- **Changes**:
  - 서브스코어 순서: HRV → RHR → Sleep (심박 관련 먼저)
  - SubScoreTrendChartView selection 제스처 확인 (이미 있음)
  - 불필요해진 ReadinessTrendChartView 삭제
  - Localization 검증 (새 문자열 xcstrings 등록)
- **Verification**: 3개 화면 스크린샷 비교 — 동일한 시각적 구조

## Canonical Section Order (통일 순서)

```
1. DetailScoreHero (sub-scores 포함)
2. ConditionInsightSection / Status 가이드 (화면별 다른 내용 허용)
3. Time-of-Day Card
4. Period Picker (7D / 30D / 90D)
5. Chart Header (visible range + trend toggle)
6. Main Trend Chart (DotLineChartView in StandardCard)
7. Summary Stats (Min / Max / Avg + 변화율)
8. Highlights (최고 / 최저 / 트렌드)
9. Sub-Score Charts (SubScoreTrendChartView ×N)
10. Component Weights (ScoreCompositionCard)
11. Contributors Card (있는 경우만)
12. Calculation Card (CalculationMethodCard — 통일 형식)
```

## Edge Cases

| Case | Handling |
|------|----------|
| 데이터 3일 미만 | 차트 empty state 표시, Summary Stats 숨김 |
| 서브스코어 일부 누락 | 가용한 서브스코어만 표시 (nil check) |
| 90일 스크롤 성능 | DotLineChartView 기존 6M/Year 성능 검증됨 (aggregation 적용) |
| Period 전환 중 로딩 | `.id(period)` + `.transition(.opacity)` + loading overlay |
| Readiness calibrating | 차트에 calibrating 배지 유지, 점수 데이터 부족 시 empty |
| Condition에 Time-of-Day | ConditionScore.timeOfDayAdjustment 확인 필요 — 없으면 섹션 조건부 숨김 |
| Wellness ViewModel 전환 | 기존 View init 파라미터 변경 → 호출부 수정 필요 |

## Testing Strategy

- **Unit tests**:
  - `TrainingReadinessDetailViewModelTests` — period 변경, extended data loading, summary stats
  - `WellnessScoreDetailViewModelTests` — period 변경, daily score 계산, summary stats
  - `ConditionScoreDetailViewModelTests` — 기존 + sub-score trend data
- **Manual verification**:
  - 3개 화면 스크린샷 비교 — 동일한 레이아웃 구조 확인
  - Period 전환 애니메이션 (shimmer, transition)
  - 차트 스크롤 + 선택 제스처 동작
  - iPad 레이아웃 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Readiness ViewModel 자립화로 데이터 불일치 | Low | Medium | 기존 approximate scoring 로직 유지, 결과 비교 검증 |
| Wellness daily score 계산 정확도 | Medium | Medium | CalculateWellnessScoreUseCase 로직 재활용 |
| HealthKit 추가 쿼리 비용 | Low | Low | extendedRange 패턴 사용, 기존 Condition에서 검증됨 |
| 호출부 변경 누락 | Low | High | Serena find_referencing_symbols로 사전 확인 |
| 긴 diff (많은 파일 변경) | High | Low | Step 단위 커밋으로 리뷰 가능 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - Condition이 이미 모든 목표 기능을 구현 → 검증된 패턴 복제
  - DotLineChartView, SubScoreTrendChartView 등 차트 컴포넌트 이미 존재
  - HealthKit 쿼리 패턴 (extendedRange, scrollDomain) 검증됨
  - DetailScoreHero 통일 이력 있음 (2026-02-28 solution)
