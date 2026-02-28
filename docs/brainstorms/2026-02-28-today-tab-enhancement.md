---
tags: [today-tab, coaching, dashboard, ux, insights]
date: 2026-02-28
category: brainstorm
status: reviewed
---

# Brainstorm: 투데이탭 코칭 강화 및 실용 콘텐츠 확충

## Problem Statement

현재 투데이탭은 Condition Score 히어로 카드와 메트릭 카드 나열 중심이다.
코칭 메시지가 컨디션 상태 5단계 기반 if/else로 단조롭고, 사용자가 매일 열어도 새로운 가치를 느끼기 어렵다.

**핵심 문제 3가지:**
1. 코칭이 얕다 — "피로하니 쉬어라" 수준. 왜 피로한지, 언제부터인지, 어떻게 회복하는지 없음
2. 콘텐츠가 정적 — 매일 같은 레이아웃, 같은 메시지 패턴. 앱을 여는 동기 부족
3. 실용 정보 부족 — "오늘 뭘 해야 하지?"에 답하지 못함

## Target Users

- 주 3-5회 운동하는 피트니스 중급자
- 데이터를 좋아하지만 해석은 앱에 맡기고 싶은 사용자
- Apple Watch를 착용하고 매일 아침 앱을 확인하는 루틴 사용자

## Success Criteria

1. 코칭 메시지가 매일 다르게 느껴질 것 (최소 20가지 고유 템플릿)
2. 사용자가 "오늘 뭘 할까?"에 대한 답을 투데이탭에서 얻을 것
3. 수면/회복 데이터가 actionable insight로 전환될 것
4. 주간 리캡으로 진전을 체감할 것

---

## Proposed Approach: 3-Layer Coaching Architecture

```
┌─────────────────────────────────────────┐
│  Layer 1: Hero Greeting + Today's Focus │  ← 감정적 연결
├─────────────────────────────────────────┤
│  Layer 2: Insight Cards (동적, 1-3개)    │  ← 실용 정보
├─────────────────────────────────────────┤
│  Layer 3: Metrics Dashboard             │  ← 데이터 확인
└─────────────────────────────────────────┘
```

### Layer 1: Hero Greeting + Today's Focus

**현재**: Condition Score 링 + 1줄 코칭 메시지
**개선**: Score 링 유지 + 컨텍스트 기반 Focus 메시지

```
┌──────────────────────────────────┐
│  좋은 아침, 성기님               │  ← 시간대 인사
│                                  │
│       [  75  ]                   │  ← Score Ring (유지)
│      Condition                   │
│                                  │
│  🟢 오늘의 포커스                │
│  "HRV가 3일 연속 상승 중입니다.  │
│   이 흐름을 유지하세요.           │
│   중강도 운동을 추천합니다."      │
│                                  │
└──────────────────────────────────┘
```

**Focus 메시지 결정 로직** (우선순위 순):

| 우선순위 | 시그널 | 메시지 예시 |
|---------|--------|------------|
| P1 | 컨디션 Warning + 3일 연속 하락 | "회복이 급합니다. 오늘은 완전한 휴식을 권합니다." |
| P2 | 수면 < 6시간 2일 연속 | "수면 부채가 쌓이고 있습니다. 오늘 일찍 취침하세요." |
| P3 | 특정 근육군 fatigue ≥ 8 | "하체 피로도가 높습니다. 상체 운동으로 전환하세요." |
| P4 | 주간 운동 목표 달성 근접 | "이번 주 목표까지 1일 남았습니다!" |
| P5 | HRV 트렌드 상승 3일+ | "컨디션이 상승 추세입니다. 강도를 올려볼 타이밍입니다." |
| P6 | HRV 트렌드 하락 3일+ | "컨디션이 하락 중입니다. 운동 볼륨을 줄여보세요." |
| P7 | 운동 공백 3일+ | "3일째 쉬고 있습니다. 가볍게 움직여볼까요?" |
| P8 | 최근 PR 달성 | "지난 벤치프레스에서 PR을 달성했습니다! 멋집니다." |
| P9 | 일반 컨디션 기반 | (현재 5단계 메시지 유지) |

**데이터 소스**: 모두 기존 도메인 모델로 커버 가능
- Condition Score + 7일 히스토리 (있음)
- Sleep Score + daily duration (있음)
- MuscleFatigue per group (있음)
- WorkoutStreak (있음)
- HRV daily averages (있음)

### Layer 2: Insight Cards (동적 1-3개)

히어로 아래, 메트릭 위에 위치하는 **동적 인사이트 카드**.
매일 데이터 상태에 따라 가장 관련 있는 1-3개만 표시.

#### Card Type A: 운동 추천 카드

```
┌──────────────────────────────────┐
│  💪 오늘의 운동 추천              │
│                                  │
│  컨디션: Good | 회복: 상체 OK    │
│                                  │
│  추천 강도: ●●●○○ 중강도         │
│  추천 부위: 상체 (가슴, 어깨)     │
│  피해야 할 부위: 하체 (피로 8/10) │
│                                  │
│  [운동 시작하기 →]               │
└──────────────────────────────────┘
```

**로직**:
- 컨디션 상태 → 추천 강도 (Warning=휴식, Tired=저강도, Fair=중강도, Good/Excellent=고강도)
- MuscleFatigue per group → 피로도 낮은 부위 추천, 높은 부위(≥7) 회피
- 최근 운동 이력 → 마지막 상체가 3일 전이면 상체 추천
- ExerciseLibrary에서 해당 부위 인기 운동 매칭

**데이터 소스**: ConditionScore + MuscleFatigue + ExerciseRecord + ExerciseLibrary (모두 있음)

#### Card Type B: 수면/회복 인사이트 카드

```
┌──────────────────────────────────┐
│  😴 수면 인사이트                 │
│                                  │
│  어젯밤: 7h 12m (점수 82)        │
│  ┌──────────────────┐            │
│  │ ■■■ deep  1h 42m │ +15min ↑  │
│  │ ■■■ rem   1h 30m │ -8min ↓   │
│  │ ■■■ core  4h 00m │           │
│  └──────────────────┘            │
│                                  │
│  💡 깊은 수면이 개선되고 있어요.  │
│     최근 3일 평균 1h 35m → 1h 42m│
│                                  │
└──────────────────────────────────┘
```

**인사이트 템플릿**:

| 시그널 | 메시지 |
|--------|--------|
| deep sleep ↑ 3일 연속 | "깊은 수면이 개선되고 있습니다. 현재 루틴을 유지하세요." |
| deep sleep < 1h | "깊은 수면이 부족합니다. 취침 전 스크린 타임을 줄여보세요." |
| sleep efficiency > 90% | "수면 효율이 높습니다. 잘 자고 계시네요!" |
| total sleep < 6h 2일+ | "수면 부채가 누적 중입니다. 이번 주말 보충 수면을 추천합니다." |
| sleep score ↑ vs 7일 평균 | "수면 품질이 주간 평균보다 높습니다." |
| bedtime 편차 > 1h | "취침 시간이 불규칙합니다. 일정한 시간에 자면 수면 품질이 올라갑니다." |

**데이터 소스**: SleepQueryService + SleepScoreCalculator (있음)

#### Card Type C: 주간 리캡 카드 (월요일 or 일요일에 표시)

```
┌──────────────────────────────────┐
│  📊 이번 주 리캡                  │
│                                  │
│  운동 4일 / 목표 5일   ●●●●○     │
│  평균 HRV: 52ms  (+3 vs 지난주)  │
│  총 볼륨: 12,450 kg  (+8%)       │
│  수면 평균: 7h 05m               │
│                                  │
│  🏆 하이라이트                    │
│  • 벤치프레스 PR: 80kg × 5       │
│  • 최장 연속 운동: 4일           │
│                                  │
│  [자세히 보기 →]                 │
└──────────────────────────────────┘
```

**데이터 소스**: WorkoutStreak + TrainingVolumeAnalysisService + HRV 7-day avg (모두 있음)

#### Card Type D: 근육 회복 상태 요약 (운동한 다음 날에 표시)

```
┌──────────────────────────────────┐
│  🔄 회복 상태                     │
│                                  │
│  어제 하체 운동 후:               │
│  대퇴사두  ████████░░  8/10 피로  │
│  햄스트링  ██████░░░░  6/10      │
│  둔근      ███████░░░  7/10      │
│                                  │
│  예상 회복: ~36시간 후 운동 가능  │
│                                  │
└──────────────────────────────────┘
```

**데이터 소스**: MuscleFatigue + RecoveryHours per muscle (있음)

### Layer 3: Metrics Dashboard (기존 유지 + 개선)

기존 핀 고정 메트릭 + 카테고리별 카드는 유지.
변경 사항:
- 카드 클릭 시 트렌드 차트에 컨텍스트 마크 추가 (운동일, PR 달성일)
- Stale 데이터(3일+)는 더 강한 시각적 구분 (현재 60% opacity → "업데이트 필요" 배지)

---

## Coaching Template System Design

### Template 구조

```swift
struct CoachingTemplate {
    let id: String
    let trigger: CoachingTrigger       // 어떤 조건에서 표시
    let priority: Int                  // 1(높음) - 9(낮음)
    let category: CoachingCategory     // recovery, training, sleep, motivation
    let titleKey: String               // 제목
    let messageKey: String             // 본문 (변수 치환 지원)
    let actionType: CoachingAction?    // 탭 시 동작
}

enum CoachingTrigger {
    case conditionWarning(consecutiveDays: Int)
    case sleepDebt(hours: Double)
    case muscleFatigueHigh(muscle: MuscleGroup, level: Int)
    case hrvTrendRising(days: Int)
    case hrvTrendFalling(days: Int)
    case workoutGap(days: Int)
    case weeklyGoalNear(remaining: Int)
    case prAchieved(exercise: String)
    case streakMilestone(days: Int)
    case weeklyRecap
    case defaultCondition(status: ConditionStatus)
}
```

### 템플릿 풀 목표: 최소 40개

| Category | 템플릿 수 | 예시 |
|----------|----------|------|
| Recovery (회복) | 8 | "3일 연속 컨디션 하락. 오버트레이닝 징후입니다." |
| Training (운동) | 10 | "상체 피로가 낮습니다. 강도를 올려볼 타이밍!" |
| Sleep (수면) | 8 | "깊은 수면 비율이 주간 평균보다 높습니다." |
| Motivation (동기) | 8 | "이번 달 15일 운동! 역대 최고 기록입니다." |
| Weekly Recap | 4 | "이번 주 총 볼륨 12,000kg. 지난주 대비 +8%." |
| Seasonal/Special | 2 | "월요일입니다. 새로운 한 주를 활기차게!" |

### 트렌드 분석 엔진 (새로 필요)

```swift
struct TrendAnalysis {
    let metric: TrendMetric           // hrv, rhr, sleepScore, volume
    let direction: TrendDirection     // rising, falling, stable
    let consecutiveDays: Int          // 연속 일수
    let changePercent: Double         // 변화율
    let significance: TrendSignificance // minor, moderate, significant
}

enum TrendDirection {
    case rising      // 3일+ 연속 상승
    case falling     // 3일+ 연속 하락
    case stable      // ±5% 이내 변동
    case volatile    // 큰 폭 변동
}
```

기존 `HealthDataAggregator`의 time-series 데이터를 활용하여
7일 윈도우 이동 평균 대비 방향을 판단.
복잡한 통계 불필요 — 단순 3일 연속 방향 일치로 충분.

---

## Constraints

### 기술적 제약
- HealthKit 데이터는 7일+ 축적 후 의미 있는 baseline 가능
- 신규 사용자(데이터 < 7일)에게는 기본 템플릿 fallback 필수
- 모든 인사이트 카드는 데이터 없음 상태 처리 필요
- 코칭 메시지는 오프라인에서도 동작해야 함 (LLM 의존 불가)

### 성능 제약
- DashboardViewModel이 이미 6개 병렬 쿼리 실행 중
- Insight 카드용 추가 계산은 기존 fetch 결과를 재활용해야 함
- 새로운 HealthKit 쿼리 추가는 최소화 (기존 서비스에서 추출)

### UX 제약
- 인사이트 카드는 최대 3개 — 정보 과부하 방지
- 카드 우선순위 로직이 명확해야 함 (왜 이 카드가 보이는지 예측 가능)
- 주간 리캡은 주 1회만 (월요일 또는 설정 가능)

---

## Edge Cases

| 케이스 | 대응 |
|--------|------|
| 신규 사용자 (데이터 0일) | 온보딩 카드: "Apple Watch를 착용하고 며칠간 데이터를 수집하세요" |
| 데이터 1-6일 | 기본 메트릭만 표시, 코칭은 generic ("건강 데이터를 수집 중입니다") |
| 데이터 7일+ | 풀 코칭 활성화 |
| 운동 기록 없음 | 근육 피로/운동 추천 카드 숨김, 수면+컨디션 중심 |
| 수면 데이터 없음 | 수면 인사이트 카드 숨김, "수면 추적을 시작하세요" 카드 대체 |
| 모든 쿼리 실패 | 캐시된 마지막 성공 데이터 + "업데이트 실패" 배너 |
| 오전 vs 오후 vs 밤 | 시간대별 인사 변경 + 운동 추천 톤 조절 |

---

## Scope

### MVP (Must-have) — Phase 1

1. **코칭 메시지 다양화 (20+ 템플릿)**
   - 트렌드 분석 엔진 (3일 연속 방향 감지)
   - 우선순위 기반 메시지 선택 (P1-P9)
   - 기존 DashboardViewModel에 통합
   - 신규 파일: `CoachingTemplateEngine` (Domain UseCase)

2. **운동 추천 Insight Card**
   - 컨디션 → 강도 매핑
   - 근육 피로 → 부위 추천
   - 기존 MuscleFatigue + ConditionScore 데이터 활용

3. **수면 인사이트 Insight Card**
   - 어젯밤 수면 요약 + 1줄 인사이트
   - 깊은 수면/총 수면/효율 기반 메시지
   - 기존 SleepQueryService 데이터 활용

4. **인사이트 카드 프레임워크**
   - 동적 카드 표시 시스템 (우선순위 기반 1-3개)
   - 카드 타입별 View 컴포넌트
   - 데이터 없음/부족 상태 처리

### Nice-to-have (Future) — Phase 2

5. **주간 리캡 카드**
   - 월요일(또는 설정 요일)에 자동 표시
   - 주간 통계 요약 + 하이라이트
   - TrainingVolumeAnalysisService 활용

6. **근육 회복 상태 카드**
   - 어제 운동한 근육의 현재 피로도
   - 예상 회복 시간
   - 운동 다음 날에만 표시

7. **동기부여 시스템**
   - 연속 기록 마일스톤 (7일, 30일, 100일)
   - 월간 최고 기록 알림
   - PR 달성 축하 카드

8. **시간대별 컨텍스트**
   - 아침: "좋은 아침" + 오늘 계획
   - 오후: "아직 운동하지 않았다면..."
   - 저녁: "오늘 잘 쉬세요" + 내일 예고

---

## Architecture Impact

### 신규 파일 (예상)

| 파일 | 위치 | 역할 |
|------|------|------|
| `TrendAnalysisService.swift` | Domain/Services/ | 트렌드 방향 감지 |
| `CoachingEngine.swift` | Domain/UseCases/ | 템플릿 선택 + 메시지 생성 |
| `CoachingTemplate.swift` | Domain/Models/ | 템플릿 모델 |
| `InsightCardData.swift` | Presentation/Shared/Models/ | 인사이트 카드 DTO |
| `WorkoutRecommendation.swift` | Domain/Models/ | 운동 추천 모델 |
| `InsightCardView.swift` | Presentation/Dashboard/Components/ | 인사이트 카드 UI |
| `WorkoutRecommendationCard.swift` | Presentation/Dashboard/Components/ | 운동 추천 카드 UI |
| `SleepInsightCard.swift` | Presentation/Dashboard/Components/ | 수면 인사이트 카드 UI |

### 기존 파일 수정 (예상)

| 파일 | 변경 |
|------|------|
| `DashboardViewModel.swift` | 인사이트 카드 데이터 빌드, 코칭 엔진 호출 |
| `DashboardView.swift` | 인사이트 카드 섹션 추가 |
| `TodayCoachingCard.swift` | 확장된 메시지 표시, 트렌드 뱃지 |

### 기존 활용 가능 서비스

| 서비스 | 활용 |
|--------|------|
| `MuscleFatigueService` | 근육별 피로도 → 운동 부위 추천 |
| `CalculateConditionScoreUseCase` | 점수 → 운동 강도 추천 |
| `SleepScoreCalculator` | 수면 점수 → 수면 인사이트 |
| `TrainingVolumeAnalysisService` | 볼륨 추세 → 주간 리캡 |
| `WorkoutStreakService` | 연속 기록 → 동기부여 |

---

## Decisions (Resolved)

1. **코칭 언어**: 존댓말 유지
2. **카드 순서**: 사용자 커스터마이즈 가능 (드래그 순서 변경 또는 우선순위 설정)
3. **주간 리캡 요일**: 월요일 (새 주 시작)
4. **운동 추천의 구체성**: ExerciseLibrary 기반 구체적 추천 (운동명 + 세트/렙 제안)
5. **인사이트 카드 dismiss**: 필요 — "오늘 하루 숨기기" (UserDefaults에 날짜별 dismiss 상태 저장)

---

## Next Steps

- [ ] `/plan today-tab-phase1` 으로 Phase 1 구현 계획 생성
- [ ] 코칭 템플릿 20개+ 한국어 초안 작성
- [ ] TrendAnalysisService 인터페이스 설계
- [ ] InsightCard 우선순위 로직 상세 설계
