---
tags: [ux, ui, data-insight, usability, dashboard, workout, consistency, research]
date: 2026-03-06
category: brainstorm
status: draft
---

# Brainstorm: UX 종합 조사 및 개선 방향성

## Problem Statement

DUNE 앱은 3/2 UX 종합 리뷰 이후 다수의 개선이 이루어졌으나(narrative message, trend badges, sleep deficit, workout recommendation 등), **데이터 인사이트 전달력**과 **사용 흐름의 일관성**에 여전히 개선 여지가 있다.

### 현재 상태 (3/6 기준)

**구현 완료된 항목 (3/2 리뷰 대비)**:
- [x] Hero 스코어 narrative message (`score.narrativeMessage`)
- [x] Trend badges (baseline comparison)
- [x] Weekly goal progress bar
- [x] Sleep deficit card (Today 탭)
- [x] Workout recommendation card
- [x] Coaching card (standalone + weather-merged)
- [x] Insight cards section
- [x] Notification hub + routing
- [x] 3D muscle map (rotatable)
- [x] 7개 테마 (Ocean, Desert, Sakura, Forest, Shanks, Hanok, Arctic)
- [x] Widget (3 sizes)
- [x] Cardio fitness (VO2 Max) tracking

**부분 구현 항목**:
- [~] Error toast — Activity 탭에 `ActivitySyncToast` 존재 (overlay + auto-dismiss), 다른 탭은 미적용
- [~] Life 탭 — empty state CTA("Add Habit") 구현, `SectionGroup` 적용, streak badges 존재. 단 weekly stats/detail 미구현
- [~] Activity Injury warning — position ②로 이동 완료
- [~] Coaching card — dismissal 존재, "View Details" CTA 미연결

**미구현 항목**:
- [ ] Hero CTA 버튼 (Start Workout / Log Weight) — 전 탭 없음
- [ ] Wellness 메트릭 계층화 (3단계) — "Physical" / "Active Indicators" 2개 섹션 유지
- [ ] Wellness 섹션 재분류 (Sleep/Cardio/Body/Recovery) — 미구현
- [ ] 코칭 통합 ("Today's Focus" 단일 섹션) — 여전히 3곳 분산
- [ ] Life 탭 depth (weekly stats, trends, detail pages) — shallow
- [ ] Life Hero가 `StandardCard` 사용 (HeroCard 아닌)
- [ ] 글로벌 에러 토스트 시스템 — Activity만 토스트 보유, 나머지 탭 없음
- [ ] 접근성 라벨 — 120+ 파일 중 15개만 보유
- [ ] iPad Split View — sizeClass 분기만 있음
- [ ] Progressive onboarding — 부분적 empty state만
- [ ] Stale 데이터 명시적 날짜 표시 — 미구현
- [ ] 차트 baseline 오버레이 — 미구현

---

## 사용자 선택 초점

1. **데이터 인사이트**: 차트/스코어 시각화 개선, 트렌드 발견, AI 기반 분석 강화
2. **사용성 개선**: 에러 처리, 로딩, 네비게이션 등 기존 기능 사용 편의성 향상
3. **시급 영역**: Dashboard/Today, 운동 기록 플로우, 전체적 일관성
4. **범위**: 조사 + 방향성 문서 (구현은 별도 계획)

---

## 영역 1: Dashboard / Today 탭 인사이트 강화

### 현재 상태
- Hero: score(숫자) + status label + narrativeMessage + sparkline + trend badges + weekly goal
- 코칭: weather card insight + standalone coaching + insight cards (3가지 분산)
- 메트릭: Condition / Activity / Body 3개 섹션, 2열 그리드
- 결측 데이터: 빈 sparkline에 대시만 표시

### 발견된 문제

| # | 문제 | 심각도 | 근거 |
|---|------|--------|------|
| T1 | **코칭이 3곳에 분산** | P2 | WeatherCard insight, TodayCoachingCard, InsightCardsSection이 각각 독립 |
| T2 | **메트릭 카드에 변화 방향 즉시 보이지 않음** | P2 | 카드 탭해야 차트에서 트렌드 확인 가능 |
| T3 | **"왜?" 설명 부재** | P2 | narrativeMessage는 상태 설명만 ("Good recovery"), 원인은 없음 ("because HRV rose 15%") |
| T4 | **Stale 데이터 시각적 구분 약함** | P3 | opacity 0.6만 적용, 명시적 "3일 전 측정" 없음 |
| T5 | **부분 로딩 실패가 조용함** | P2 | HealthKit 쿼리 일부 실패 시 로그만 남김 |

### 개선 방향

**T1 해결 — 코칭 통합**:
```
현재: Weather insight + Coaching card + Insight cards (3개 분산)
제안: "Today's Focus" 단일 섹션으로 통합
      우선순위: Injury alert > Sleep deficit > Weather risk > Training suggestion > General coaching
```

**T2 해결 — 메트릭 카드 마이크로 트렌드**:
```
현재: [HRV: 42ms]          제안: [HRV: 42ms ▲3%]
      [RHR: 58bpm]                [RHR: 58bpm ●0%]
      (변화 정보 없음)             (7일 대비 변화 표시)
```

**T3 해결 — Causal narrative**:
```
현재: "Good recovery"
제안: "Good recovery — HRV rose 15% after quality sleep"
구현: ConditionScore에 topContributor: String? 추가
```

---

## 영역 2: 운동 기록 플로우

### 현재 플로우
```
Activity 탭 → (+) 또는 WorkoutRecommendationCard → ExerciseStartView
→ 운동 선택 → 세트 기록 → 완료
```

### 발견된 문제

| # | 문제 | 심각도 | 근거 |
|---|------|--------|------|
| W1 | **운동 시작 CTA가 toolbar (+)에만** | P1 | Hero 영역에 primary action 없음, 스크롤 필요 |
| W2 | **Suggested Workout이 Hero 바로 아래가 아님** | P2 | Muscle Map, Weekly Stats 아래에 위치할 수 있음 |
| W3 | **운동 완료 후 피드백이 약함** | P2 | 성공 햅틱만, 요약 화면이나 celebration 없음 |
| W4 | **세트 입력 중 이전 기록 참조 어려움** | P2 | 같은 운동의 지난 기록을 보려면 별도 탐색 필요 |
| W5 | **Injury 경고가 운동 선택 단계에서 보이지 않음** | P2 | Activity 탭에서는 position ②에 표시되지만, ExerciseStartView에서는 없음 |

### 개선 방향

**W1 해결 — Hero CTA**:
```
┌─────────────────────────┐
│  ○ Readiness: 78        │
│  "Ready for training"   │
│  ━━━━━ 7d sparkline     │
│                         │
│  [▶ START WORKOUT]      │ ← Primary CTA
└─────────────────────────┘
```

**W3 해결 — 운동 완료 요약**:
```
┌─────────────────────────┐
│  🎉 Workout Complete    │
│                         │
│  Duration: 45 min       │
│  Volume: 12,400 kg      │
│  Sets: 18               │
│  Est. Calories: 280     │
│                         │
│  🏆 New PR: Squat 100kg│
│                         │
│  [Share] [Done]         │
└─────────────────────────┘
```

**W4 해결 — 인라인 이전 기록**:
```
세트 입력 시:
┌─────────────────────────┐
│ Set 3 of Bench Press    │
│ Weight: [80] kg         │
│ Reps:   [8]             │
│ ─────────────────────── │
│ 📋 Last session (3/4):  │
│   80kg × 10, 85kg × 8  │
└─────────────────────────┘
```

---

## 영역 3: 전체적 UX 일관성

### 현재 불일치 현황

| 패턴 | Dashboard | Activity | Wellness | Life |
|------|-----------|----------|----------|------|
| Hero card | ConditionHero (rich) | ReadinessHero (rich) | WellnessHero (rich) | StandardCard (basic) |
| Section grouping | SectionGroup | SectionGroup | Mixed | None |
| Empty state | EmptyStateView + action | EmptyStateView | EmptyStateView | 텍스트만 |
| Error handling | errorBanner | Banner | Banner | 없음 |
| Loading | Skeleton | ProgressView | ProgressView | 없음 |
| Haptic feedback | Chart selection | Chart + set complete | Chart selection | 없음 |
| CTA 버튼 | 없음 | (+) toolbar | 없음 | (+) toolbar |
| 탭 depth | 5 sections + detail | 8+ sections + detail | 2 sections + detail | 1 list, 0 detail |

### 개선 방향

**일관성 프레임워크** — 모든 탭이 따라야 할 공통 구조:

```
┌─────────────────────────┐
│ 1. Hero (Score + Narrative + CTA)
├─────────────────────────┤
│ 2. Alert/Warning (Injury, Sleep debt 등)
├─────────────────────────┤
│ 3. Primary Content (각 탭 고유)
├─────────────────────────┤
│ 4. Secondary Content (상세 메트릭)
├─────────────────────────┤
│ 5. Footer (Updated timestamp)
└─────────────────────────┘
```

**Life 탭 depth 확장 제안**:
```
현재: Hero ring + flat habit list
제안:
  1. Hero: completion ring + streak + narrative
  2. Today's Habits: 체크리스트 (현재와 동일)
  3. Weekly Overview: 7일 completion heatmap
  4. Stats: completion rate, best streaks, trends
  5. Detail: 개별 습관 탭 → streak chart + history
```

**Error/Loading 통일**:

| 상태 | 통일 패턴 | 현재 커버리지 |
|------|----------|-------------|
| Loading (첫 로드) | Skeleton view (`.redacted`) | Dashboard만 |
| Loading (재로드) | Wave refreshable | 전 탭 |
| Error (non-fatal) | Inline banner (접을 수 있음) | Dashboard만 |
| Error (fatal) | EmptyStateView + retry action | 부분 구현 |
| Empty (첫 사용) | EmptyStateView + CTA + 가이드 | 탭별 불일치 |
| Partial failure | "N of M sources" 배너 | 로그만 |

---

## 영역 4: 데이터 인사이트 시각화

### 현재 차트 시스템

- 26개 차트 파일 (`Presentation/Shared/Charts/`)
- AXChartDescriptor 접근성 (3종류)
- `.sensoryFeedback(.selection)` 적용
- Period 전환 (`.id(period)` + `.transition(.opacity)`)
- Selection overlay (`.overlay(alignment: .top)` + `.ultraThinMaterial`)

### 발견된 개선 기회

| # | 영역 | 현재 | 제안 |
|---|------|------|------|
| I1 | **Baseline 비교** | 절대값만 표시 | "Your average" 기준선 오버레이 |
| I2 | **트렌드 해석** | 사용자가 차트를 읽어야 함 | "3-week upward trend" 자동 감지 + 텍스트 |
| I3 | **상관관계 발견** | 메트릭별 독립 차트 | "Sleep ↑ → HRV ↑ correlation" 인사이트 |
| I4 | **Goal context** | 숫자만 표시 | "15% above your 30-day average" |
| I5 | **Period 비교** | 단일 기간만 | "vs last week" 비교 모드 |

### Insight Engine 아키텍처 방향

```
Layer 1: Raw Data (HealthKit → SwiftData)
    ↓
Layer 2: Statistical Analysis (mean, std, trend regression)
    ↓
Layer 3: Pattern Detection (correlation, anomaly, streak)
    ↓
Layer 4: Narrative Generation (template-based text)
    ↓
Layer 5: UI Rendering (InsightCard, ChartAnnotation, HeroBadge)
```

현재는 Layer 1-2까지만 존재. Layer 3-5를 단계적으로 구축하는 것이 데이터 인사이트 강화의 핵심.

---

## 영역 5: 접근성 & 품질 기반

### 접근성 현황

| 항목 | 현재 | 목표 |
|------|------|------|
| `.accessibilityLabel` | 28개 (15 파일) | 120+ 파일 전체 커버 |
| Dynamic Type | 미지원 | `@ScaledMetric` 적용 |
| VoiceOver 차트 | AXChartDescriptor 3종 | 전 차트 타입 커버 |
| 색상 대비 | 미검증 | WCAG AA 준수 |
| Reduce Motion | 부분 지원 | 전 애니메이션 대응 |

### 에러 처리 UX 현황

```
현재:
  Activity 탭: ActivitySyncToast (overlay, auto-dismiss 3.5초) ← 좋은 패턴
  Wellness 탭: InlineCard partialFailureBanner
  Dashboard 탭: errorBanner (inline text)
  Life 탭: 없음

제안: ActivitySyncToast 패턴을 전역 토스트로 추출
  에러 → 분류 (fatal/recoverable/info)
       ↓
      fatal → EmptyStateView + retry
      recoverable → 전역 Toast (ActivitySyncToast 패턴, auto-dismiss 3.5초)
      info → "N of M" 상태 표시
```

---

## 우선순위별 로드맵 (방향성)

### Phase 1: 일관성 기반 (Quick Wins)

| ID | 작업 | 효과 | 예상 규모 |
|----|------|------|----------|
| P1-1 | 전 탭 Hero에 CTA 버튼 추가 | Actionability ↑↑ | 4개 Hero 수정 |
| P1-2 | 코칭 카드 통합 ("Today's Focus") | 인지 부하 ↓ | Dashboard 리팩토링 |
| P1-3 | 메트릭 카드에 변화율(▲/▼/●) 표시 | 즉시 이해 가능 | VitalCard 수정 |
| ~~P1-4~~ | ~~Life 탭 empty state에 CTA 추가~~ | ~~첫 사용 경험 ↑~~ | ✅ 구현 완료 |
| P1-5 | Stale 데이터에 "N일 전" 명시 | 데이터 신뢰도 ↑ | VitalCard 수정 |

### Phase 2: 인사이트 강화 (Medium Effort)

| ID | 작업 | 효과 | 예상 규모 |
|----|------|------|----------|
| P2-1 | Causal narrative ("because HRV...") | 이해도 ↑↑ | Score 모델 + Hero |
| P2-2 | 차트 baseline 오버레이 | 맥락 제공 ↑ | Chart 컴포넌트 |
| P2-3 | 운동 완료 요약 화면 | 만족감 ↑ | 새 View |
| P2-4 | 세트 입력 시 이전 기록 인라인 표시 | 효율 ↑ | 운동 기록 View |
| P2-5 | Error toast 시스템 전역 확장 | 에러 가시성 ↑ | Activity `ActivitySyncToast` 패턴을 전 탭에 적용 |

### Phase 3: 시스템 확장 (Major Effort)

| ID | 작업 | 효과 | 예상 규모 |
|----|------|------|----------|
| P3-1 | Life 탭 depth 확장 (stats, streaks, trends) | 탭 균형 ↑ | 5+ 새 View |
| P3-2 | Wellness 메트릭 3단계 계층화 | 인지 부하 ↓↓ | Wellness 리팩토링 |
| P3-3 | Insight Engine Layer 3-4 (pattern + narrative) | 데이터 가치 ↑↑↑ | 새 UseCase |
| P3-4 | 접근성 전면 적용 | 사용자 범위 ↑ | 120+ 파일 |
| P3-5 | iPad NavigationSplitView | iPad 경험 ↑ | 전 탭 layout |

---

## 크로스커팅 디자인 원칙

### 1. Glanceable → Actionable → Insightful

모든 화면이 3단계 정보 밀도를 제공:
- **Glanceable**: 1초 내 핵심 정보 파악 (score + trend arrow)
- **Actionable**: 3초 내 다음 행동 결정 (CTA + coaching)
- **Insightful**: 탭하면 깊은 분석 (chart + correlation + history)

### 2. Progressive Disclosure

빈 화면 → 데이터 수집 중 → 기본 메트릭 → 트렌드 → 인사이트 순서로 정보 노출.
"7일 데이터 수집 중 (3/7일)" 같은 진행 상황 표시.

### 3. Consistent Error Language

에러 메시지 톤: "We couldn't load X. Pull down to try again."
기술적 디테일은 숨기고, 사용자 행동을 안내.

---

## Open Questions

1. **Insight Engine 깊이**: 단순 통계 기반 텍스트 vs 온디바이스 ML 기반 패턴 인식?
2. **운동 완료 요약의 소셜 공유**: 이미지 생성 + 공유 기능까지 포함할지?
3. **Wellness 계층화 기준**: 사용자 개인화(자주 보는 메트릭) vs 의학적 중요도?
4. **Life 탭 최종 비전**: 단순 체크리스트 vs 건강 지표와 연계된 습관-건강 상관관계?
5. **접근성 우선순위**: WCAG AA 전면 적용 vs 핵심 플로우만 우선?
6. **Watch complication**: 위젯은 있으나 Watch complication은 필요한가?

---

## 참고: 이전 UX 리뷰 대비 변화

| 영역 | 3/2 리뷰 시점 | 3/6 현재 | 변화 |
|------|-------------|---------|------|
| Hero narrative | 없음 | `narrativeMessage` + status label | ✅ 구현 |
| Trend badges | 없음 | `BaselineTrendBadge` | ✅ 구현 |
| Weekly goal | 없음 | `weeklyGoalProgress` ProgressView | ✅ 구현 |
| Sleep deficit | 없음 | `sleepDeficitSection` | ✅ 구현 |
| Workout recommendation | 없음 | `WorkoutRecommendationCard` | ✅ 구현 |
| Notification hub | 기본 | 라우팅 + inbox actions + dedup | ✅ 대폭 개선 |
| 3D Muscle map | 2D | Rotatable 3D flow | ✅ 구현 |
| 테마 | 4개 | 7개 (Shanks, Hanok, Arctic 추가) | ✅ 확장 |
| Widget | 없음 | 3-size WidgetKit | ✅ 구현 |
| Injury warning 위치 | 하단 | position ② (hero 바로 아래) | ✅ 구현 |
| Life empty state CTA | 없음 | "Add Habit" 버튼 | ✅ 구현 |
| Life SectionGroup | 없음 | habits + achievements 섹션 | ✅ 구현 |
| Error toast | 없음 | Activity 탭 `ActivitySyncToast` | ⚠️ 부분 (1탭만) |
| Hero CTA | 없음 | 없음 | ❌ 미구현 |
| Coaching 통합 | 3곳 분산 | 여전히 분산 | ❌ 미구현 |
| Life 탭 depth | Flat list | 약간 개선 (streak badges) | ⚠️ 부분 |
| Wellness 계층화 | 없음 | 없음 | ❌ 미구현 |
| 접근성 | 28 labels | 약간 증가 추정 | ⚠️ 부분 |

---

## Scope

### MVP (이 문서의 범위)
- 현재 UX 상태 종합 조사 ✅
- 3/2 리뷰 대비 변화 추적 ✅
- 개선 방향성 및 우선순위 제안 ✅

### 구현 (별도 계획)
- Phase 1-3 각 항목은 별도 `/plan`으로 구현 계획 생성
- 운동 기록 플로우 개선은 별도 brainstorm 가능

## Next Steps

- [ ] 사용자 피드백 후 Phase 1 항목 확정
- [ ] Phase 1 개별 항목에 대해 `/plan` 생성
- [ ] Insight Engine 아키텍처는 별도 `/brainstorm` 권장
- [ ] Life 탭 확장은 별도 `/brainstorm` 권장
