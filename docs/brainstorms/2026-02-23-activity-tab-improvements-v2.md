---
tags: [activity, training-readiness, recovery-map, weekly-stats, detail-view, iPad, layout]
date: 2026-02-23
category: brainstorm
status: draft
---

# Brainstorm: Activity Tab Improvements v2

## Problem Statement

Activity 탭의 3가지 UX 개선 포인트:
1. **Training Readiness Hero Card**가 탭 불가 — 상세 화면이 없어서 사용자가 점수 구성 요소를 더 깊이 탐색할 수 없음
2. **Recovery Map**이 iPhone에서 좌우 정렬이 어색함 — HStack이 화면 가운데에 정확히 위치하지 않는 느낌
3. **This Week** 섹션에 상세 화면 없음 — 4개 stat 카드를 탭해도 일별/주간 트렌드를 확인할 수 없음
4. **iPad 가로모드**에서 Recovery Map 섹션의 빈 공간이 과도함 — 넓은 화면을 효율적으로 활용하지 못함

## Target Users

- 매일 운동 데이터를 확인하는 활발한 사용자
- iPad로 대시보드를 확인하는 사용자 (특히 가로모드)

## Success Criteria

- Training Readiness Hero Card 탭 → 상세 화면 push
- Recovery Map이 iPhone compact에서 시각적으로 가운데 정렬
- This Week 탭 → 일별 차트 + 운동 타입별 breakdown이 있는 상세 화면 push
- iPad 가로모드에서 Recovery Map + This Week가 나란히 배치되어 빈 공간 해소

## Proposed Approach

### 1. Training Readiness Detail View

**현재**: `TrainingReadinessHeroCard`는 readiness score, status, sub-scores(HRV/Sleep/Recovery)를 보여주지만 탭 불가.

**개선**: Hero Card 전체를 NavigationLink로 감싸서 상세 화면으로 push.

**상세 화면 내용 (후보)**:
- Training Readiness Score 큰 원형 게이지
- Sub-score 각각의 7일 트렌드 차트 (HRV, Sleep Quality, Recovery/Fatigue)
- Readiness 히스토리 (최근 7~30일 line chart)
- 구성 요소별 가중치/해석 설명
- 운동 추천 가이드 (현재 readiness 기반)

**Navigation 패턴**: `ActivityDetailDestination`에 `.trainingReadiness` case 추가 → 기존 패턴 활용.

### 2. Recovery Map iPhone 센터 정렬

**현재**: `HStack { bodyDiagram(front) bodyDiagram(back) }` — GeometryReader + aspectRatio 사용. 최대 높이 300.

**문제**: HStack 자체는 가운데지만, GeometryReader 내부에서 width/height 계산 시 정렬이 미묘하게 어긋날 수 있음.

**개선안**:
- `HStack` 에 `.frame(maxWidth: .infinity)` + alignment 확인
- `bodyDiagramSection`에 명시적 센터 정렬 보장
- 필요 시 `Spacer()` 또는 `frame(maxWidth:)` 조정

### 3. This Week Detail View

**현재**: `WeeklyStatsGrid`가 4개 `ActivityStat` 카드를 2x2 LazyVGrid로 표시. 탭 불가.

**개선**: SectionGroup 전체 또는 각 카드를 NavigationLink로 감싸서 상세 화면으로 push.

**상세 화면 내용**:
- **일별 Bar Chart**: Volume / Calories / Duration을 일별로 표시 (Segmented Picker로 전환)
- **주간 비교**: 이번 주 vs 지난 주 비교 통계
- **운동 타입별 breakdown**: 웨이트 / 유산소 / 기타로 분류한 비율 + 각 타입 상세

**Navigation 패턴**: `ActivityDetailDestination`에 `.weeklyStats` case 추가.

### 4. iPad 가로모드 Recovery Map 레이아웃

**현재**: iPhone과 동일한 세로 스크롤 레이아웃. iPad 가로모드에서 Recovery Map이 가운데 작게 표시되고 양옆이 빈 공간.

**개선안 — Recovery Map + This Week 나란히 배치**:
```
iPad Landscape:
┌────────────────────────────────┐
│ Training Readiness Hero Card   │
├──────────────┬─────────────────┤
│ Recovery Map │ This Week Stats │
│  (front/back)│  (2x2 grid)    │
│              │                 │
├──────────────┴─────────────────┤
│ Suggested Workout              │
│ ...                            │
└────────────────────────────────┘
```

**구현 방법**:
- `@Environment(\.horizontalSizeClass)` 감지
- `sizeClass == .regular` + landscape일 때 `HStack` 레이아웃
- Recovery Map과 This Week를 나란히 배치
- compact에서는 현재대로 VStack 유지

**대안**: ViewThatFits 또는 `Layout` protocol로 반응형 처리.

## Constraints

- **기존 Navigation 패턴 준수**: `ActivityDetailDestination` enum 확장 (Correction #61, #93)
- **SectionGroup 구조 유지**: `SectionGroup(title:icon:)` wrapper는 변경 최소화
- **iPad 가로/세로 전환 시 View 재생성 방지**: `@State` 캡처 패턴 (Correction #10)
- **body 내 Calendar 연산 캐싱** (Correction #102)
- **HealthKit 쿼리 병렬화** (Correction #5)

## Edge Cases

- **데이터 없음**: Training Readiness nil / weeklyStats 빈 배열 — emptyState 표시 필수
- **iPad multitasking**: Split View에서 sizeClass 전환 시 레이아웃 깨짐 방지
- **iPad 세로모드**: 세로에서는 iPhone과 유사한 VStack 레이아웃 유지
- **HRV/Sleep 데이터 부족**: 상세 화면에서 calibrating 상태 표시

## Scope

### MVP (Must-have)
- [ ] Training Readiness Hero Card → 상세 화면 push (NavigationLink)
- [ ] Training Readiness Detail View + ViewModel
- [ ] Recovery Map iPhone 센터 정렬 미세 조정
- [ ] This Week → 상세 화면 push (NavigationLink)
- [ ] This Week Detail View + ViewModel (일별 차트 + 타입별 breakdown)
- [ ] iPad 가로모드: Recovery Map + This Week 나란히 배치

### Nice-to-have (Future)
- Training Readiness 30일 히스토리 차트
- This Week 상세에서 목표 설정 기능
- Recovery Map iPad에서 인터랙티브 3D 느낌

## Resolved Questions

1. **Training Readiness 트렌드 기간**: 14일
2. **This Week 기간 전환**: 필요 (이번 주 / 지난 주 / 이번 달)
3. **iPad 레이아웃**: Recovery Map + This Week 기본안 + 더 나은 방안 제안 가능

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
