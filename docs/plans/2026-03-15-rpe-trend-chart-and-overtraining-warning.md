---
topic: rpe-trend-chart-and-overtraining-warning
date: 2026-03-15
status: approved
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-12-set-rpe-integration.md
  - docs/solutions/architecture/2026-03-12-watch-rpe-auto-estimation.md
related_brainstorms:
  - docs/brainstorms/2026-03-12-watch-rpe-auto-estimation.md
---

# Implementation Plan: RPE Trend Chart + Overtraining Warning

## Context

RPE(주관적 운동 강도) 시스템이 MVP로 완성되었으나, 수집된 RPE 데이터를 활용한 분석/시각화가 부족하다.
두 가지 1순위 기능을 추가한다:

1. **RPE 트렌드 차트**: 28일간 일별 평균 RPE를 시각화하여 훈련 강도 추이를 파악
2. **과훈련 경고**: 연속 고RPE 세션을 감지하여 CoachingEngine 인사이트로 경고

## Requirements

### Functional

- 28일간 일별 평균 RPE를 BarMark 차트로 표시 (Activity 탭 Training Volume 섹션)
- RPE 강도 구간별 색상 구분 (Light/Moderate/Hard/Max)
- 7일 이동평균 LineMark 오버레이
- 연속 3회 이상 고RPE(≥8) 세션 시 CoachingEngine에서 과훈련 경고 생성
- 경고는 Dashboard 코칭 카드로 표시

### Non-functional

- ExerciseRecord.rpe (Int?, 1-10) 기존 데이터 활용
- 기존 TrainingLoadChartView 패턴 재사용
- 기존 CoachingEngine 트리거 패턴 준수
- en/ko/ja 3개 언어 번역

## Approach

### Feature 1: RPE Trend Chart

TrainingLoadChartView의 구조를 미러링하여 `RPETrendChartView`를 생성한다.
데이터 소스는 `ExerciseRecord.rpe`를 일별로 집계하고,
`TrainingVolumeViewModel`에서 기존 `recentRecords`를 활용하여 차트 데이터를 생성한다.

### Feature 2: Overtraining Warning

`CoachingInput`에 `recentHighRPEStreak: Int` 필드를 추가하고,
`CoachingEngine.evaluateRecoveryTriggers()`에 RPE 기반 과훈련 감지 트리거를 추가한다.
`DashboardViewModel.buildCoachingInsights()`에서 최근 ExerciseRecord를 분석하여 streak을 계산한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| LineMark 전용 차트 (SubScoreTrendChart 패턴) | 부드러운 트렌드 | RPE 없는 날 구분 어려움 | 기각: BarMark가 일별 존재 여부를 명확히 표현 |
| TrainingVolumeDetailView에 탭으로 추가 | 기존 화면 확장 | 주요 지표가 숨겨짐 | 기각: 독립 섹션이 가시성 높음 |
| RPE streak을 별도 서비스로 분리 | 테스트 용이 | 과잉 설계 | 기각: CoachingEngine 내 inline이 패턴 일관성 유지 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Activity/Components/RPETrendChartView.swift` | NEW | RPE 28일 BarMark 차트 |
| `Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | MODIFY | RPE 차트 데이터 계산 추가 |
| `Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | MODIFY | RPE 차트 섹션 추가 |
| `Domain/UseCases/CoachingEngine.swift` | MODIFY | RPE 기반 과훈련 트리거 추가 |
| `Domain/UseCases/CoachingEngine.swift` (CoachingInput) | MODIFY | `recentHighRPEStreak` 필드 추가 |
| `Presentation/Dashboard/DashboardViewModel.swift` | MODIFY | RPE streak 계산 및 CoachingInput 전달 |
| `DUNETests/RPETrendChartDataTests.swift` | NEW | 차트 데이터 집계 로직 테스트 |
| `DUNETests/CoachingEngineRPETests.swift` | NEW | RPE 과훈련 트리거 테스트 |
| `Shared/Resources/Localizable.xcstrings` | MODIFY | 새 문자열 en/ko/ja 번역 |

## Implementation Steps

### Step 1: RPE 차트 데이터 모델 + 집계 로직

- **Files**: `TrainingVolumeViewModel.swift`
- **Changes**:
  - `RPETrendDataPoint` struct 추가 (date, averageRPE, sessionCount)
  - `rpeTrendData: [RPETrendDataPoint]` 프로퍼티 추가
  - `loadData(manualRecords:)`에서 ExerciseRecord.rpe를 일별 평균으로 집계
  - RPE가 nil인 레코드는 제외
- **Verification**: 프로퍼티가 정상적으로 데이터를 채우는지 단위 테스트

### Step 2: RPETrendChartView 생성

- **Files**: `Presentation/Activity/Components/RPETrendChartView.swift` (NEW)
- **Changes**:
  - TrainingLoadChartView 구조 미러링
  - BarMark로 일별 평균 RPE 표시
  - RPE 구간별 색상: 1-4 Light(green), 5-6 Moderate(yellow), 7-8 Hard(orange), 9-10 Max(red)
  - 7일 이동평균 LineMark 오버레이
  - 차트 선택 오버레이 (기존 scrollableChartSelectionOverlay 재사용)
  - Y축 도메인: 0-10 고정
  - 높이: 140pt, `.clipped()` 필수
- **Verification**: Preview에서 목데이터로 렌더링 확인

### Step 3: TrainingVolumeDetailView에 RPE 차트 섹션 배치

- **Files**: `Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift`
- **Changes**:
  - Training Load 차트 아래에 RPE Trend 섹션 추가
  - 데이터가 없으면 섹션 숨김
- **Verification**: Activity 탭 → Training Volume 상세에서 RPE 차트 표시

### Step 4: CoachingInput에 RPE streak 필드 추가

- **Files**: `Domain/UseCases/CoachingEngine.swift`
- **Changes**:
  - `CoachingInput`에 `recentHighRPEStreak: Int` 필드 추가 (기본값 0)
  - `evaluateRecoveryTriggers()`에 RPE 기반 트리거 추가:
    - streak ≥ 3: P2 "Training intensity has been high" 경고
    - streak ≥ 5: P1 "Overtraining risk from sustained high effort" 경고
- **Verification**: 단위 테스트로 트리거 발동 확인

### Step 5: DashboardViewModel에서 RPE streak 계산

- **Files**: `Presentation/Dashboard/DashboardViewModel.swift`
- **Changes**:
  - `buildCoachingInsights()`에서 recentRecords를 날짜순으로 정렬
  - 최근 연속 고RPE(≥8) 세션 수를 계산
  - `CoachingInput.recentHighRPEStreak`에 전달
- **Verification**: streak 계산 로직 확인

### Step 6: 단위 테스트 작성

- **Files**: `DUNETests/RPETrendChartDataTests.swift` (NEW), `DUNETests/CoachingEngineRPETests.swift` (NEW)
- **Changes**:
  - RPE 일별 집계: 빈 데이터, 단일 세션, 복수 세션, nil RPE 제외
  - 이동평균 계산 정확성
  - CoachingEngine RPE streak: streak 0/2/3/5에 대한 인사이트 생성 검증
- **Verification**: 테스트 전체 통과

### Step 7: Localization

- **Files**: `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - "RPE Trend" → ko: "RPE 추이", ja: "RPEトレンド"
  - "Avg RPE" → ko: "평균 RPE", ja: "平均RPE"
  - "Training intensity has been high" → ko/ja 번역
  - "Overtraining risk from sustained high effort" → ko/ja 번역
  - 기타 UI 문자열
- **Verification**: 각 locale에서 문자열 확인

## Edge Cases

| Case | Handling |
|------|----------|
| RPE 데이터 0건 (신규 사용자) | 차트 섹션 숨김 (placeholder 없음) |
| 하루에 여러 세션 | 일별 평균으로 집계 |
| 모든 세션 RPE가 nil | 차트 숨김 (rpe 입력 안 한 사용자) |
| streak 중간에 RPE nil 세션 | nil 세션은 streak 중단으로 처리 |
| streak 중간에 운동 안 한 날 | 날짜 기반이 아닌 세션 기반 streak (연속 세션) |

## Testing Strategy

- Unit tests: RPE 집계, 이동평균, streak 계산, CoachingEngine 트리거
- Manual verification: Activity 탭에서 RPE 차트 렌더링, Dashboard에서 경고 카드 표시
- Edge case: 빈 데이터, 단일 데이터, 대량 데이터

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| RPE 데이터 희소 (사용자가 입력 안 함) | Medium | Low | 차트 숨김 처리 |
| CoachingInput 변경으로 다른 코드 영향 | Low | Medium | 기본값 0으로 backward compatible |
| 차트 성능 (28일 × 여러 세션) | Low | Low | 집계 데이터가 최대 28개 포인트 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 TrainingLoadChartView와 CoachingEngine 패턴이 잘 정립되어 있어 미러링 구현. 새 API 도입 없음. 데이터 소스(ExerciseRecord.rpe) 확보 완료.
