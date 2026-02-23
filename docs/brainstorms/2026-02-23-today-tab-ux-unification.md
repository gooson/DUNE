---
tags: [today-tab, ux, unification, wellness, component-sharing, vital-card, section-group]
date: 2026-02-23
category: brainstorm
status: draft
---

# Brainstorm: Today 탭 UX 통합 (Wellness 스타일)

## Problem Statement

기존 플랜(2026-02-22)의 기능적 개선(히어로+코칭, 핀카드, baseline 추세, 신선도 라벨)은 모두 구현 완료되었으나, Today 탭과 Wellness 탭의 **시각적 일관성**이 부족하다:

- Today: `MetricCardView` + `SmartCardGrid` + 텍스트 헤더
- Wellness: `VitalCard` + `SectionGroup` + `LazyVGrid` 2열 고정

같은 앱 안에서 탭마다 카드 스타일과 섹션 구조가 다르면 사용자 경험이 분절된다.

## Target Users

- Apple Watch 사용자: 아침에 Today에서 상태 확인 → Wellness에서 추세 확인하는 흐름
- 동일한 데이터(HRV, RHR 등)가 탭에 따라 다른 카드로 보이면 혼동

## Success Criteria

- [ ] Today와 Wellness에서 동일 메트릭이 동일한 카드 스타일로 표시
- [ ] 섹션 헤더가 양쪽 탭에서 동일한 컴포넌트(SectionGroup) 사용
- [ ] Today 카드에 sparkline이 추가되어 Wellness와 동일한 정보 밀도 확보
- [ ] Today에만 있는 baseline 배지가 통합 카드에서도 지원
- [ ] 기존 기능(핀카드 편집, 코칭, baseline 추세) 회귀 없음

## Current State Analysis

### 기존 플랜 구현 현황 (6/6 완료)

| Step | 설명 | 상태 |
|------|------|------|
| 1 | Pinned Metrics 저장소 | **완료** |
| 2 | DashboardViewModel 로직 확장 | **완료** |
| 3 | Hero + Coaching UI 통합 | **완료** |
| 4 | Pinned 섹션 + 편집 흐름 | **완료** |
| 5 | 신선도 라벨 표준화 | **완료** |
| 6 | Baseline 추세 표시 + 테스트 | **완료** |

### MetricCardView vs VitalCard 차이

| 특성 | MetricCardView (Today) | VitalCard (Wellness) |
|------|----------------------|---------------------|
| 입력 타입 | `HealthMetric` 직접 | `VitalCardData` DTO |
| Sparkline | 없음 | 필수 (MiniSparklineView) |
| Baseline 배지 | BaselineTrendBadge 통합 | 없음 |
| 신선도 | `Date.freshnessLabel` | 커스텀 `staleLabel` |
| 변화 표시 | `changeDirectionIcon` + `formattedChangeValue` | `changeLabel()` helper |
| 컨테이너 | `.thinMaterial` + RoundedRectangle | `StandardCard` wrapper |
| 오래된 데이터 | opacity 0.84 | opacity 0.6 |

### 섹션 컨테이너 차이

| 특성 | Today | Wellness |
|------|-------|----------|
| 헤더 | `Text("Health Signals")` | `SectionGroup(title:icon:iconColor:)` |
| 그리드 | `SmartCardGrid` (유동적) | `LazyVGrid` 2열 고정 |
| 섹션 분류 | Pinned → Health Signals → Activity | Physical → Active Indicators → Injury |

## Proposed Approach

### 1) VitalCard 확장: Baseline 배지 지원 추가

VitalCard에 optional `BaselineDetail` 프로퍼티를 추가하여 Today와 Wellness 모두에서 사용 가능하게 만든다.

```
VitalCard 통합 구조:
┌─────────────────────────┐
│ Icon  Title    [Stale?] │
│                         │
│ Value Unit   ↗Change%   │
│ [vs 14d avg ↗+2.3]     │  ← baseline 배지 (Today만 표시)
│ ┌─────────────────────┐ │
│ │   Mini Sparkline    │ │  ← sparkline (양쪽 표시)
│ └─────────────────────┘ │
└─────────────────────────┘
```

- Wellness: sparkline + change (기존 유지)
- Today: sparkline + change + baseline 배지 (확장)

### 2) VitalCardData 확장: Sparkline + Baseline 통합

`VitalCardData`에 다음 필드 추가:
- `baselineDetail: BaselineDetail?` — baseline 배지용 (nil이면 미표시)
- `inversePolarity: Bool` — RHR처럼 낮을수록 좋은 지표용

DashboardViewModel에서 VitalCardData 변환 로직 추가:
- 기존 `HealthMetric` → `VitalCardData` 변환 (WellnessViewModel 패턴 재사용)
- sparkline 데이터 포함 (7일 데이터 → `[Double]`)

### 3) SectionGroup으로 섹션 헤더 통합

Today 탭의 섹션을 SectionGroup으로 교체:

```
현재 Today:                         통합 후 Today:
─────────────                       ─────────────
[Hero]                              [Hero]
[Coaching]                          [Coaching]
"Pinned Metrics" [Edit]             SectionGroup("Pinned", pin.fill, .accent) [Edit]
  SmartCardGrid                       LazyVGrid 2열 → VitalCard
"Health Signals"                    SectionGroup("Condition", heart.fill, .red)
  SmartCardGrid                       LazyVGrid 2열 → VitalCard
"Activity"                          SectionGroup("Activity", figure.run, .green)
  SmartCardGrid                       LazyVGrid 2열 → VitalCard
```

### 4) 섹션 재그룹 (Wellness 방식 의미 기반)

Hero 유지 + Wellness 방식 분류 차용:

| 섹션 | 포함 메트릭 | 아이콘 | 색상 |
|------|-----------|--------|------|
| Pinned | 사용자 선택 Top 3 | `pin.fill` | accent |
| Condition | HRV, RHR | `heart.fill` | red |
| Activity | Steps, Exercise | `figure.run` | green |
| Body | Weight, BMI, Sleep | `bed.double.fill` | blue |

> Sleep을 Body에 넣는 이유: Wellness 탭에서도 Physical 섹션에 Sleep이 포함되어 있어 일관성 유지.

### 5) SmartCardGrid → LazyVGrid 교체

`SmartCardGrid`의 유동적 열 대신 Wellness와 동일한 2열 고정 `LazyVGrid` 사용:
- iPhone: 2열
- iPad: 기존 `SmartCardGrid`가 3열이었으나, Wellness 패턴 통일을 위해 2열 유지 (카드 내 정보 밀도가 더 높으므로)

### 6) 신선도 라벨 통합

VitalCard의 `staleLabel`을 `Date.freshnessLabel`로 교체하여 단일 소스로 통합.

## Constraints

- **기존 기능 회귀 방지**: 핀카드 편집, 코칭, baseline 추세, 신선도 라벨 모두 유지
- **데이터 흐름 변경 범위**: DashboardViewModel이 VitalCardData 변환 추가 필요
- **Sparkline 데이터**: Today에서도 7일 데이터가 필요 — 현재 DashboardViewModel에서 일부 수집 중
- **아키텍처 경계**: ViewModel에 SwiftUI import 금지 유지

## Edge Cases

| Case | Handling |
|------|----------|
| Sparkline 데이터 2점 미만 | VitalCard 기존 동작: 대시 플레이스홀더 |
| Baseline 없는 메트릭 | baselineDetail = nil → 배지 미표시 |
| 핀 메트릭이 섹션 분류와 중복 | Pinned에 표시된 메트릭은 하단 섹션에서 제외 (기존 동작 유지) |
| iPad 레이아웃 | 2열 고정으로 Wellness와 동일하게 동작 |

## Scope

### MVP (Must-have)

1. VitalCard에 `baselineDetail` 프로퍼티 추가
2. DashboardViewModel에서 `HealthMetric` → `VitalCardData` 변환 로직 추가
3. Today 섹션 헤더를 SectionGroup으로 교체
4. Today 섹션을 의미 기반 재그룹 (Condition / Activity / Body)
5. SmartCardGrid → LazyVGrid 2열로 교체
6. 신선도 라벨 단일 소스 통합
7. MetricCardView 사용처 제거 (VitalCard로 완전 대체)
8. VitalCard 탭 햅틱 피드백 (`.sensoryFeedback(.impact(weight: .light), trigger:)`)
9. 카드 입장 staggered 애니메이션 (`.transition(.opacity.combined(with: .move(edge: .bottom)))` + 인덱스별 delay)

### Nice-to-have (Future)

- Activity 탭도 동일 패턴으로 통합
- iPad에서 3열 적응형 레이아웃

## Migration Plan

MetricCardView → VitalCard 이전 시:

1. VitalCard 확장 (baseline 지원)
2. DashboardViewModel에 VitalCardData 변환 추가
3. DashboardView에서 MetricCardView → VitalCard 교체
4. SmartCardGrid 사용처 제거 → LazyVGrid
5. 섹션 헤더 SectionGroup 교체
6. MetricCardView 파일 삭제 (dead code 제거)
7. WellnessView의 staleLabel → freshnessLabel 통합

## Open Questions

- 없음 (모든 결정 완료)

## Next Steps

- [ ] `/plan today-tab-ux-unification` 으로 구현 계획 생성
