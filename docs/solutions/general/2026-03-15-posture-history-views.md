---
tags: [posture, history, trend-chart, comparison, swiftui, swiftdata]
date: 2026-03-15
category: general
status: implemented
---

# Posture History, Trend Chart & Comparison Views

## Problem

Phase 3의 Posture 기능 (TODOs #124-127)으로, 사용자가 과거 자세 평가를 조회하고 시간 경과에 따른 트렌드를 확인하며 두 평가를 비교할 수 있는 뷰가 필요했음.

## Solution

### 구조

| 파일 | 역할 |
|------|------|
| `PostureHistoryViewModel` | 통계 계산, 차트 데이터, 비교 델타, 메트릭 필터 |
| `PostureHistoryView` | @Query 기반 히스토리 리스트, 차트, 필터 pills, 통계 카드 |
| `PostureDetailView` | 단일 기록 상세 (점수, 이미지+조인트 오버레이, 메트릭 리스트) |
| `PostureComparisonView` | 두 기록 나란히 비교 (점수 델타, 이미지 비교, 메트릭 변화) |

### 핵심 패턴

1. **DotLineChartView 재사용**: 기존 `ChartDataPoint` + `DotLineChartView` 활용. 전체 점수 또는 개별 메트릭 점수를 `selectedMetricFilter`에 따라 전환.

2. **비교 선택 패턴**: `Set<UUID>` (최대 2개) + `toggleComparison()` + `comparisonPair` computed property. `Set`을 `Array`로 변환할 때 force-index 대신 안전한 optional 튜플 반환.

3. **MetricDelta 구조체**: `comparisonDelta(older:newer:)` → `[MetricDelta]`. 한쪽에만 있는 메트릭도 처리 (`oldScore: nil` 또는 `newScore: nil`).

4. **네비게이션**: `PostureRecordDestination` / `PostureComparisonDestination` value types + `.navigationDestination(for:)` 패턴.

### 리뷰에서 발견된 주요 문제와 해결

| 문제 | 해결 |
|------|------|
| `scoreColor` 4개 파일 중복 | `PostureMetric+View.swift`에 `postureScoreColor()` 추출 |
| `formattedValue` 3개 파일 중복 | 동일 파일에 `formattedPostureMetricValue()` 추출 |
| 비교 arrow.right 양쪽 동일 (버그) | `arrow.up.right` / `arrow.down.right`로 수정 |
| `Set<UUID>` force-index 크래시 가능 | `comparisonPair` optional computed property로 안전 추출 |
| 점수 ring trim 범위 미클램프 | `min(1, max(0, CGFloat(score)/100.0))` 방어 |
| DetailView 삭제 확인 없음 | `.alert` 확인 다이얼로그 추가 |
| DetailView DS 토큰 미사용 | `DS.Spacing`/`DS.Radius` 통일 + `DetailWaveBackground` |
| 비교 모드 터치 영역 10pt | 전체 행 `onTapGesture`로 확대 |

## Prevention

- 새 Posture 뷰 추가 시 `postureScoreColor()` / `formattedPostureMetricValue()` 재사용
- `Set`에서 인덱스 접근 시 반드시 안전한 추출 패턴 사용
- `DetailWaveBackground` + DS 토큰을 기본으로 적용
- 삭제 버튼은 반드시 `.alert` 확인 경유
