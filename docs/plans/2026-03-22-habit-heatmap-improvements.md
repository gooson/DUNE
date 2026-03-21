---
tags: [life, heatmap, activity, ui, detail-view]
date: 2026-03-22
category: plan
status: approved
---

# Plan: 활동(Activity) 히트맵 섹션 개선

## Problem Statement

Life 탭의 "활동" 히트맵 섹션에 3가지 문제가 있다:

1. **너비 미맞춤**: 셀 크기가 12px 고정이라 카드 너비에 관계없이 그리드가 왼쪽에 쏠리고 우측에 빈 공간이 발생
2. **상세 화면 없음**: 히트맵을 탭해도 아무 반응 없음. 다른 카드 섹션과 달리 drill-down이 불가
3. **설명 부재**: "Less"/"More" 범례만 있고 이 그리드가 무엇을 나타내는지 설명 없음

## Affected Files

| 파일 | 변경 유형 |
|------|----------|
| `DUNE/Presentation/Life/HabitHeatmapView.swift` | 수정 — 너비 맞춤, 설명 텍스트 추가, 탭 내비게이션 |
| `DUNE/Presentation/Life/HabitHeatmapDetailView.swift` | **신규** — 상세 화면 |
| `DUNE/Presentation/Life/LifeView.swift` | 수정 — navigationDestination 연결, 상세 데이터 전달 |
| `Shared/Resources/Localizable.xcstrings` | 수정 — 새 문자열 en/ko/ja 등록 |

## Implementation Steps

### Step 1: HabitHeatmapView 너비 맞춤

**문제**: `cellSize = 12`, `cellSpacing = 2` 고정 → 카드 너비에 따라 우측 공백 발생

**해결**: `GeometryReader`로 사용 가능 너비를 측정하고, 주 수(columns)를 기반으로 셀 크기를 동적 계산.

- 90일 데이터 → 약 13주(열) → 7행(요일)
- dayLabel 폭(20pt + 2pt padding) 제외한 가용 너비 기준으로 cellSize 역산
- `cellSize = (availableWidth - dayLabelWidth - (columns - 1) * spacing) / columns`
- 최소 cellSize 8pt, 최대 16pt로 클램프

### Step 2: 설명 텍스트 추가

타이틀 "Activity" 아래에 한 줄 설명 추가:
- "Daily habit completion over the last 90 days"
- `String(localized:)` 래핑, xcstrings에 ko/ja 등록

### Step 3: HabitHeatmapDetailView 신규 생성

상세 화면 구성:
1. **헤더**: 기간 + 총 completion 수 요약
2. **확대 히트맵**: 전체 너비, 월 라벨 포함
3. **통계 카드들**:
   - 가장 활발했던 요일 (weekday 집계)
   - 최장 연속일 (streak 계산)
   - 일일 평균 completion 수
4. **월별 요약 차트**: 월별 합계 바 차트

패턴: `WeeklyHabitReportView`와 동일한 카드+DetailWaveBackground 구조

### Step 4: 내비게이션 연결

- `HabitHeatmapView` 전체를 Button으로 감싸거나, 우측 상단 chevron 추가
- `LifeView`의 `analyticsSection`에 `@State private var showingHeatmapDetail = false` 추가
- `navigationDestination(isPresented:)` 으로 상세 화면 push

### Step 5: Localization

새 문자열 xcstrings 등록 (en/ko/ja):
- "Daily habit completion over the last 90 days"
- "Activity Detail"
- "Most Active Day"
- "Longest Streak"
- "Daily Average"
- 기타 상세 화면 레이블

## Test Strategy

- `HabitAnalyticsServiceTests`에 streak 계산 + 요일별 집계 테스트 추가
- 빌드 검증: `scripts/build-ios.sh`

## Risks & Edge Cases

- **데이터 0건**: 히트맵이 빈 상태에서 상세 화면 진입 → 빈 상태 메시지 표시
- **셀 크기 너무 작아짐**: 가용 너비가 매우 좁은 경우(iPad split view 등) → minCellSize 클램프
- **성능**: 90일 데이터는 630개 셀 → LazyHGrid로 이미 처리 중, 문제 없음
