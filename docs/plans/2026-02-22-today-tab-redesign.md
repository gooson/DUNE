---
topic: today-tab-redesign
date: 2026-02-22
status: draft
confidence: high
related_solutions:
  - performance/2026-02-16-review-triage-task-cancellation-and-caching.md
  - general/2026-02-16-six-perspective-review-application.md
  - general/2026-02-17-chart-ux-layout-stability.md
related_brainstorms:
  - 2026-02-22-today-tab-expert-reference-brainstorm.md
---

# Implementation Plan: Today Tab Redesign (상태판단 + 습관동기)

## Context

Today 탭은 현재 `Health Signals`/`Activity` 카드 나열 중심이라 "지금 어떤 상태인지"와 "오늘 무엇을 해야 하는지"를 즉시 판단하기 어렵습니다.

2026-02-22 결정사항:
- 목적: **상태판단 + 습관동기**
- 성공 지표: **주간 목표 달성률**
- 타깃: **운동 중심 사용자**
- 범위: **UI + 로직** (데이터 모델 대규모 변경 제외)
- MVP: **히어로+코칭 / 핀 카드+신선도 / baseline 추세**

## Requirements

### Functional

1. Today 상단에 **Hero + Coaching** 영역을 배치한다.
2. 사용자 지정 **Pinned Metrics Top 3**를 지원한다.
3. 모든 카드에 **데이터 신선도 라벨**(`Today`, `Yesterday`, `Nd ago`)을 표시한다.
4. 핵심 지표에 대해 **단기(전일) + baseline(14일/60일)** 비교를 제공한다.
5. Hero에서 **주간 목표 진행도**(예: active days 5일 목표)를 보여준다.
6. 기존 partial failure 동작을 유지하고, 데이터 부족 시 보수적 코칭을 제공한다.

### Non-functional

- 기존 레이어 경계 유지:
  - ViewModel: `import Observation` only
  - Domain 모델 수정 최소화
- 기존 cancellation/parallel fetch 패턴 유지 (Correction #16, #17, #25)
- iPhone/iPad 레이아웃 안정성 유지
- Dynamic Type/VoiceOver 접근성 유지

## Approach

기존 `DashboardViewModel`과 `MetricCardView`를 확장하는 **점진적 리팩터링**으로 구현합니다.

핵심 전략:
- 새로운 데이터 타입 추가 없이, 이미 조회 중인 HealthKit 데이터로 MVP 달성
- 고정값이 아닌 사용자 선호를 반영하기 위해 Top 3 핀 카드를 UserDefaults 저장
- 코칭은 진단 문구가 아닌 행동 제안 문구로 제한

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Today 전용 새 ViewModel 작성 | 구조가 깔끔함 | 기존 fallback/테스트 자산 재사용 어려움 | 기각 |
| 기존 DashboardViewModel 확장 | 변경 범위 작고 안전함 | ViewModel 책임이 다소 증가 | 채택 |
| Training Readiness 모델 완전 통합 | 운동 중심 맥락 강화 | Activity 탭 로직 중복, 스코프 증가 | MVP에서는 보류 |

## Affected Files

### 신규 생성

| File | Description |
|------|-------------|
| `Dailve/Data/Persistence/TodayPinnedMetricsStore.swift` | Top 3 pinned metric 카테고리 저장/검증 |
| `Dailve/Presentation/Dashboard/Components/TodayCoachingCard.swift` | 오늘의 행동 1개 제안 카드 |
| `Dailve/Presentation/Dashboard/Components/BaselineTrendBadge.swift` | 전일/14일/60일 비교 표시 컴포넌트 |
| `Dailve/Presentation/Dashboard/Components/PinnedMetricsEditorView.swift` | 핀 카드 편집 sheet |
| `DailveTests/TodayPinnedMetricsStoreTests.swift` | pinned metrics persistence 테스트 |

### 수정

| File | Change Type | Description |
|------|-------------|-------------|
| `Dailve/Presentation/Dashboard/DashboardView.swift` | Major | Hero 섹션 재도입, Pinned 섹션, 편집 진입점 추가 |
| `Dailve/Presentation/Dashboard/DashboardViewModel.swift` | Major | 코칭 생성, baseline 계산, pinned metric 필터링, 주간 목표 진행도 |
| `Dailve/Presentation/Dashboard/Components/ConditionHeroView.swift` | Major | 코칭/주간 목표/baseline 배지 통합 |
| `Dailve/Presentation/Dashboard/Components/MetricCardView.swift` | Minor | 신선도 라벨 표준화 및 baseline 보조 텍스트 |
| `Dailve/Presentation/Shared/Extensions/Date+Validation.swift` | Minor | 신선도 라벨 확장 (`Today`, `Yesterday`, `Nd ago`) |
| `DailveTests/DashboardViewModelTests.swift` | Major | baseline 계산/코칭/pinned 정렬 테스트 추가 |

## Implementation Steps

### Step 1: Pinned Metrics 저장소 추가

- **Files**: `TodayPinnedMetricsStore.swift`, `TodayPinnedMetricsStoreTests.swift`
- **Changes**:
  - `UserDefaults` 기반 store 구현 (`bundleIdentifier` prefix 적용)
  - 저장 형식: `[HealthMetric.Category.RawValue]`
  - 유효 카테고리 화이트리스트: `.hrv`, `.rhr`, `.sleep`, `.steps`, `.exercise`, `.weight`, `.bmi`
  - 기본값: `hrv`, `rhr`, `sleep`
  - 3개 초과/중복/잘못된 값 입력 시 정규화
- **Verification**:
  - 기본값 로드
  - 중복 제거
  - invalid rawValue 무시
  - 저장 후 재시작 시 복원

### Step 2: DashboardViewModel 로직 확장

- **Files**: `DashboardViewModel.swift`
- **Changes**:
  - 상태 추가:
    - `pinnedCategories: [HealthMetric.Category]`
    - `pinnedMetrics: [HealthMetric]`
    - `coachingMessage: String?`
    - `weeklyGoalProgress: (completedDays: Int, goalDays: Int)`
    - `baselineDeltasByMetricID: [String: BaselineDelta]`
  - `loadData()` 후처리 추가:
    - pinned metric 계산
    - 코칭 문구 생성 (`ConditionScore`, Sleep, Exercise 기반)
    - 주간 active days 계산 (workout 7일 데이터 재사용)
  - baseline 계산:
    - HRV: `fetchHRVSamples(days: 60)`으로 14/60일 평균 대비
    - RHR: `fetchRHRCollection(..., interval: day)` 60일 평균 대비
    - Sleep/Steps/Exercise: 가능한 경우 14일 평균 대비
  - partial failure 정책 유지
- **Verification**:
  - existing fallback 테스트 회귀 없음
  - baseline 계산 nil-safe
  - data 없는 경우에도 loadData가 실패하지 않음

### Step 3: Hero + Coaching UI 통합

- **Files**: `ConditionHeroView.swift`, `TodayCoachingCard.swift`, `BaselineTrendBadge.swift`, `DashboardView.swift`
- **Changes**:
  - `ConditionHeroView`를 Today 최상단에 재배치
  - Hero 하단에 다음 정보 추가:
    - `오늘 행동 1개` 코칭 문구
    - 주간 목표 진행도 (`3/5 days`)와 진행 바
    - baseline 배지(`vs yesterday`, `vs 14d`, `vs 60d`)
  - 데이터 부족 시 conservative 메시지 노출:
    - 예: "데이터가 충분하지 않아 저강도 활동을 권장합니다"
- **Verification**:
  - Hero 유무 분기 (score 존재/부재)
  - 코칭 문구 줄바꿈/접근성 라벨 확인
  - iPad/Compact 레이아웃 확인

### Step 4: Pinned Metrics 섹션 + 편집 흐름

- **Files**: `DashboardView.swift`, `PinnedMetricsEditorView.swift`, `DashboardViewModel.swift`
- **Changes**:
  - Today 상단에 `Pinned Metrics` 섹션 추가 (Top 3)
  - `Edit` 버튼 탭 시 sheet에서 카테고리 선택
  - 선택 즉시 저장 + 화면 반영
  - 미선택 메트릭은 기존 `Health Signals`/`Activity` 섹션에 유지
- **Verification**:
  - 편집 후 즉시 UI 반영
  - 앱 재실행 후 선택 유지
  - 3개 제한 정확히 동작

### Step 5: 신선도 라벨 표준화

- **Files**: `Date+Validation.swift`, `MetricCardView.swift`
- **Changes**:
  - `relativeLabel` 확장:
    - today: `Today`
    - yesterday: `Yesterday`
    - N days: `Nd ago`
  - historical 여부와 무관하게 라벨 표기 가능하도록 카드 로직 통일
  - 오래된 데이터(`>3d`)는 보조색/투명도로 신뢰도 시각화
- **Verification**:
  - 날짜 케이스별 라벨 문자열 테스트
  - 라벨 표시로 인한 카드 높이 변동 최소화 확인

### Step 6: baseline 추세 표시 + 테스트 보강

- **Files**: `BaselineTrendBadge.swift`, `MetricCardView.swift`, `DashboardViewModelTests.swift`
- **Changes**:
  - 지표별 baseline 델타를 뱃지/서브텍스트로 노출
  - 표시 우선순위:
    - 1순위: `vs yesterday`
    - 2순위: `vs 14d avg`
    - 3순위: `vs 60d avg` (데이터 있을 때)
  - 운동 중심 타깃을 위해 Exercise/Steps에 주간 누적 대비 진행 상태 노출
- **Verification**:
  - baseline 계산 경계 테스트 (분모 0, 표본 부족, NaN)
  - 피처 플로우 수동 검증:
    - 데이터 충분한 사용자
    - 아침 이른 시간(당일 데이터 부족)
    - 권한 부분 허용 사용자

## Edge Cases

| Case | Handling |
|------|----------|
| 조건 점수 없음 | Hero는 empty state + 일반 코칭 메시지 노출 |
| HRV만 있고 Sleep 없음 | 코칭 강도를 보수적으로 하향 |
| 오래된 데이터만 존재 | `Nd ago` 라벨 + 강조도 낮춤 |
| 사용자 핀 구성이 모두 무효 | 기본 3개(`hrv`, `rhr`, `sleep`)로 fallback |
| 일부 소스 실패 | 기존 non-blocking 에러 배너 유지 |

## Testing Strategy

- Unit tests:
  - `TodayPinnedMetricsStoreTests` 신규
  - `DashboardViewModelTests`에 baseline/coaching/pinned 케이스 추가
- Integration tests:
  - `DashboardViewModel.loadData()` 후 섹션 데이터 일관성 검증
- Manual verification:
  - iPhone/iPad 레이아웃
  - 앱 재실행 후 pinned 복원
  - HealthKit 데이터 부족 상태에서 코칭 문구 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| DashboardViewModel 비대화 | Medium | Medium | 계산 로직을 private helper로 분리, follow-up에서 UseCase 추출 |
| baseline 계산 비용 증가 | Medium | Medium | 필요한 카테고리만 계산, 비동기 병렬화 유지 |
| 코칭 문구의 과도한 확정 표현 | Low | High | 행동 제안형 문구만 사용, 진단/치료 표현 금지 |
| 기존 섹션 레이아웃 회귀 | Medium | Medium | 스냅샷 수준 수동 검증 + iPad 확인 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 코드 자산(`DashboardViewModel`, fallback, 테스트, 카드 컴포넌트)을 재사용하며, 스코프를 UI+로직으로 제한해 이번 스프린트 내 완료 가능성이 높습니다.
