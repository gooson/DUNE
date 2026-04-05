---
tags: [dashboard, stress, detail-view, score-detail, canonical-layout, hourly-snapshot]
date: 2026-04-05
category: architecture
status: implemented
---

# CumulativeStress Detail View (ConditionScore급 Full)

## Problem

투데이 탭의 CumulativeStressCard가 30일 스트레스 점수를 요약 표시하지만:
1. 사용자가 스트레스 점수의 의미와 계산 방식을 이해할 수 없음
2. 상세 화면이 없어 기여 요소 분석, 트렌드 차트, 개선 가이드 제공 불가
3. 히스토리가 저장되지 않아 과거 추이를 볼 수 없음

## Solution

### 1. HourlyScoreSnapshot 확장 (히스토리 저장)

- `stressScore: Double?` 필드 추가 (additive optional → lightweight migration)
- `ScoreRefreshService.recordSnapshot()`에 `stressScore: Int?` 파라미터 추가
- DashboardViewModel에서 계산된 스트레스 점수를 recordSnapshot에 전달

### 2. CumulativeStressDetailView (Canonical Layout)

ConditionScoreDetailView 패턴을 따라 10개 섹션 구성:

```
Hero (DetailScoreHero) → Stress Insight → Contributors → Level Guide (신규)
→ Period Picker → Chart Header → DotLineChart → Summary Stats → Highlights
→ Score Composition → Explainer (신규)
```

### 3. 신규 컴포넌트

- **CumulativeStressExplainerSection**: 4개 항목 (스트레스 정의, HRV 40%, 수면 35%, 활동 25%)
- **CumulativeStressLevelGuide**: 4단계 레벨 (Low/Moderate/Elevated/High) 의미 + 현재 위치

### 4. 공유 Extension

- `CumulativeStressScore.Contribution.Factor`에 `color`, `iconName`, `displayName` 추가
- CumulativeStressCard와 DetailView 양쪽에서 재사용 (DRY)

## Key Decisions

1. **HourlyScoreSnapshot 확장 vs 별도 모델**: 기존 인프라(ScoreRefreshService) 재사용, additive field → migration 불필요
2. **ViewModel이 ScoreRefreshService에서 직접 조회**: fetchStressSnapshots() 메서드 추가, 일별 평균으로 집계
3. **staggeredAppear index 고유화**: 리뷰에서 index 충돌 발견 → 순차 0-8 할당
4. **isRegular computed property**: swiftui-patterns.md 규칙 준수

## Prevention

- 새 Score Detail View 추가 시 ConditionScoreDetailView canonical layout을 반드시 참조
- staggeredAppear index는 형제 노드 간 고유해야 함 (같은 index = 동시 애니메이션)
- Factor/Level 관련 View extension은 `{Type}+View.swift`에 통합하여 DRY 유지

## Lessons Learned

- `fetchLimit: 2000`은 30일 × 24시간 = 720개보다 넉넉하지만, 장기간 사용 시 상한 검토 필요
- 히스토리 저장은 첫 저장 시점부터만 데이터가 쌓이므로, 기존 사용자는 차트가 비어 있을 수 있음 → ScoreDetailEmptyState로 처리
