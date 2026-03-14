---
topic: posture-history-trend
date: 2026-03-15
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-15-posture-visualization-enhancement.md
  - docs/solutions/architecture/2026-03-15-posture-assessment-vision-3d-pose.md
related_brainstorms:
  - docs/brainstorms/2026-03-15-posture-assessment-system.md
---

# Implementation Plan: Posture History + Trend (Phase 3)

## Context

Posture assessment Phase 1 (capture + analysis) 과 Phase 2 (visualization enhancement) 가 완료된 상태.
사용자가 과거 측정 기록을 확인하고, 시간에 따른 트렌드를 파악하며, 두 시점을 비교할 수 있는 Phase 3 기능을 구현한다.

관련 TODOs: #124 (History List), #125 (Trend Chart), #126 (Before/After Comparison), #127 (Per-Metric Change Analysis)

## Requirements

### Functional

- 날짜순 자세 측정 히스토리 리스트 (점수, 썸네일, 메모 미리보기)
- 탭하면 기존 PostureResultView 기반 상세 화면으로 이동
- 주간/월간 Posture Score 트렌드 차트 (기존 DotLineChartView 재사용)
- 개별 지표별 트렌드 drill-down
- 두 시점 비교 (사진 + 점수 변화 + 개별 지표 변화량)
- 지표별 개선/악화 추세 표시

### Non-functional

- 기존 ExerciseHistoryView / DotLineChartView 패턴 일관성 유지
- SwiftData @Query는 isolated child view에서 수행 (WellnessView 패턴)
- DS 토큰 사용 (Spacing, Radius, Color)
- Localization 3개 언어 (en/ko/ja)
- Accessibility labels

## Approach

기존 앱 패턴을 최대한 재사용:
- **History list**: InjuryHistoryView 패턴 (List + @Query + NavigationLink)
- **Trend chart**: DotLineChartView + ChartDataPoint 재사용
- **Comparison**: 새 뷰이나 PostureResultView의 captureImageCard 패턴 차용
- **Per-metric analysis**: PostureMetricType.allCases 순회, score delta 계산

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 별도 ViewModel | 테스트 용이 | ViewModel 증가 | 채택 — 히스토리 로직 분리 |
| @Query 직접 사용 | 코드 간결 | parent rerender | 채택 — child view 격리로 해결 |
| Custom chart | 완전 맞춤 | 유지보수 | 거부 — DotLineChartView 재사용 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Posture/PostureHistoryView.swift` | New | 히스토리 리스트 + 트렌드 차트 |
| `DUNE/Presentation/Posture/PostureDetailView.swift` | New | 저장된 record 상세 뷰 (읽기 전용) |
| `DUNE/Presentation/Posture/PostureComparisonView.swift` | New | 두 시점 비교 뷰 |
| `DUNE/Presentation/Posture/PostureHistoryViewModel.swift` | New | 히스토리 데이터 처리 + 트렌드 계산 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | Modify | PostureHistoryDestination 연결 |
| `DUNE/DUNETests/PostureHistoryViewModelTests.swift` | New | ViewModel 유닛 테스트 |
| `Shared/Resources/Localizable.xcstrings` | Modify | 새 문자열 번역 추가 |

## Implementation Steps

### Step 1: PostureHistoryViewModel

- **Files**: `PostureHistoryViewModel.swift`
- **Changes**:
  - `@Observable @MainActor` ViewModel
  - `loadHistory(from: [PostureAssessmentRecord])` → 차트 데이터 + 통계 계산
  - `chartData: [ChartDataPoint]` (overallScore by date)
  - `metricTrendData(for: PostureMetricType) -> [ChartDataPoint]` (개별 지표 트렌드)
  - `selectedMetricFilter: PostureMetricType?` for drill-down
  - `comparisonPair: (PostureAssessmentRecord, PostureAssessmentRecord)?` for comparison
  - `statistics`: 평균 점수, 최고/최저, 총 측정 횟수, 변화율
- **Verification**: Unit test 통과

### Step 2: PostureHistoryView (리스트 + 차트)

- **Files**: `PostureHistoryView.swift`
- **Changes**:
  - @Query로 PostureAssessmentRecord 조회 (date desc)
  - 상단: Trend chart (DotLineChartView)
  - 지표 필터 (horizontal scroll pills, ExerciseHistoryView 패턴)
  - Stats cards (평균 점수, 측정 횟수, 변화율)
  - 하단: 히스토리 리스트 (날짜, 점수 원형, 지표 수, 메모 미리보기)
  - 비교 모드 진입 버튼
  - NavigationLink → PostureDetailView
- **Verification**: Preview에서 레이아웃 확인

### Step 3: PostureDetailView (읽기 전용 상세)

- **Files**: `PostureDetailView.swift`
- **Changes**:
  - PostureAssessmentRecord를 받아 읽기 전용으로 표시
  - PostureResultView의 score/metrics/images 패턴 재사용
  - 메모 표시 (편집 불가)
  - 삭제 버튼 (with confirmation)
- **Verification**: NavigationLink 탐색 동작

### Step 4: PostureComparisonView (비교)

- **Files**: `PostureComparisonView.swift`
- **Changes**:
  - 두 record 받아 나란히 비교
  - 사진 비교 (side by side, JointOverlay 포함)
  - 점수 변화 (delta 표시, 개선=초록, 악화=빨강)
  - 개별 지표 변화량 테이블
- **Verification**: 두 record 선택 후 비교 동작

### Step 5: WellnessView 연결

- **Files**: `WellnessView.swift`
- **Changes**:
  - `.navigationDestination(for: PostureHistoryDestination.self)` 추가
  - PostureHistoryView로 연결
- **Verification**: "View All" 탭 → 히스토리 화면 이동

### Step 6: Localization + Tests

- **Files**: `Localizable.xcstrings`, `PostureHistoryViewModelTests.swift`
- **Changes**:
  - 새 문자열 en/ko/ja 등록
  - ViewModel 유닛 테스트 (chartData 생성, statistics, comparison delta)
- **Verification**: 테스트 통과, xcstrings 키 매칭

## Edge Cases

| Case | Handling |
|------|----------|
| 측정 기록 0건 | ContentUnavailableView 표시 |
| 측정 기록 1건 | 차트 대신 단일 데이터 포인트 뷰 표시, 비교 버튼 비활성 |
| 전면만 / 측면만 캡처된 record | partial 표시, 빈 쪽은 placeholder |
| 비교 시 두 record의 지표 종류가 다른 경우 | 공통 지표만 delta 표시, 고유 지표는 단독 표시 |
| 매우 오래된 record (이미지 없음 가능) | imageData nil 처리, placeholder |

## Testing Strategy

- Unit tests: PostureHistoryViewModel (chartData, statistics, metricTrend, comparison delta)
- Manual verification: 히스토리 리스트 스크롤, 차트 표시, 비교 화면 레이아웃
- Localization: 3개 언어 키 등록 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| @Query가 많은 record에서 느림 | Low | Medium | fetchLimit 적용 |
| Image 로딩으로 메모리 증가 | Medium | Medium | 리스트에서는 thumbnail용 소형 이미지만 표시 |
| JointOverlay 좌표가 저장된 record에서 안 맞음 | Low | Low | 기존 JointOverlayView 그대로 사용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 ExerciseHistoryView, DotLineChartView, InjuryHistoryView 패턴을 충실히 따르는 구현. 새 API나 프레임워크 도입 없음.
