---
tags: [wave, design-system, color, tab-identity, animation, watch]
date: 2026-02-27
category: brainstorm
status: approved
---

# Brainstorm: 웨이브 전면 확산 + 탭별 아이덴티티 컬러

## Problem Statement

현재 웨이브 배경이 3개 탭 루트 + Exercise 화면에만 적용되어 있고, **모든 화면의 웨이브 파라미터가 동일**하며, **Activity(녹색)와 Wellness(녹색)의 키컬러가 거의 구분되지 않는다.**

### 현황 분석

**웨이브 적용 화면 (4곳)**
| 화면 | 키컬러 | 웨이브 파라미터 |
|------|--------|----------------|
| DashboardView | warmGlow (0.79, 0.58, 0.42) | amp 0.06, freq 2, offset 0.5 |
| ActivityView | activity (0.34, 0.72, 0.48) | 동일 |
| WellnessView | fitness (0.42, 0.71, 0.34) | 동일 |
| ExerciseView | activity (0.34, 0.72, 0.48) | 동일 |

**웨이브 미적용 화면 (~30곳)**
- Detail 화면: ConditionScoreDetail, WellnessScoreDetail, MetricDetail, AllData, BodyHistoryDetail, TrainingReadinessDetail, WeeklyStatsDetail, ExerciseMixDetail, PersonalRecordsDetail, TrainingVolumeDetail, ExerciseTypeDetail, ConsistencyDetail, ExerciseSessionDetail, HealthKitWorkoutDetail, VolumeAnalysis
- Injury 화면: InjuryHistory, InjuryStatistics, InjuryBodyMap
- Sheet/Modal: ExerciseStart, WorkoutSession, CompoundWorkout, CreateCustomExercise, ExercisePicker, UserCategoryManagement, PinnedMetricsEditor, RestTimer, CreateTemplate, CloudSyncConsent
- Watch: 전체 (ContentView, QuickStartPicker, SessionPaging, SessionSummary 등)

**핵심 문제: 컬러 유사성**
- `DS.Color.activity` = (0.337, 0.718, 0.478) — 녹색
- `DS.Color.fitness` = (0.420, 0.706, 0.337) — 거의 같은 녹색
- Hue 차이 약 15도로, 나란히 놓으면 구분 가능하지만 탭 전환 시 구분 어려움

## Success Criteria

1. 어떤 탭에 있는지 웨이브 컬러만으로 직관적 인지 가능
2. Detail/Sheet 화면에서도 소속 탭의 시각적 맥락 유지
3. 탭별 웨이브 모션이 미묘하게 다른 캐릭터를 가짐
4. Watch 앱에도 브랜드 일관성 확장
5. 기존 DS 토큰 체계와 자연스럽게 통합

## Proposed Approach

### Phase 1: 웨이브 전면 확산 (Push 1)

**1-A. `TabWaveBackground` → 모든 ScrollView 기반 화면에 적용**

적용 전략:
- **Tab Root**: 기존 유지 (Dashboard, Activity, Wellness, Exercise)
- **Detail View (push)**: 부모 탭의 컬러를 Environment로 전달
- **Sheet/Modal**: 해당 맥락의 키컬러 사용 (Exercise 관련 → Train 컬러)
- **Watch**: 간소화된 웨이브 (단일 레이어, 작은 amplitude)

**1-B. 탭별 웨이브 파라미터 차별화**

| 탭 | amplitude | frequency | layers | 캐릭터 |
|----|-----------|-----------|--------|--------|
| Today | 0.04 | 1.5 | 1 | 느리고 부드러운 — 차분한 모니터링 |
| Train | 0.08 | 2.5 | 2 (메인+서브) | 역동적이고 에너지틱 — 활동 |
| Wellness | 0.05 | 1.8 | 1 | 완만하고 넓은 — 안정과 균형 |

Train 탭의 이중 레이어:
- 메인 웨이브: amplitude 0.08, frequency 2.5, opacity 0.15
- 서브 웨이브: amplitude 0.04, frequency 3.5, opacity 0.08, phase offset π/3

**1-C. Environment 기반 컬러 전파**

```swift
// 새 EnvironmentKey
private struct TabWaveColorKey: EnvironmentKey {
    static let defaultValue: Color = DS.Color.warmGlow
}

extension EnvironmentValues {
    var tabWaveColor: Color { ... }
}

// ContentView에서 설정
Tab(...) {
    NavigationStack {
        DashboardView(...)
    }
    .environment(\.tabWaveColor, DS.Color.warmGlow)
}

// Detail View에서 자동 사용
struct MetricDetailView: View {
    @Environment(\.tabWaveColor) private var waveColor
    // ...
    .background { DetailWaveBackground(primaryColor: waveColor) }
}
```

**1-D. Detail용 웨이브 변형**

Detail 화면은 Tab Root보다 subtle하게:
- amplitude 50% 감소
- opacity 70% 수준
- height 150pt (탭 루트 200pt보다 작게)

**1-E. Sheet/Modal용 웨이브**

Sheet은 더욱 미니멀하게:
- 단일 웨이브, amplitude 30% 감소
- 상단 gradient만 (wave overlay 생략 가능)
- NavigationStack 내부에서 사용하므로 독립적

**1-F. Watch 웨이브**

watchOS는 화면이 작으므로:
- 단일 웨이브, amplitude 0.03, frequency 1.5
- height: 80pt
- warmGlow 컬러 단일 사용 (탭 구분 불필요)
- `WaveShape`를 Watch 타겟에도 공유 (shared file)

### Phase 2: 탭 아이덴티티 컬러 재정의 (Push 2)

**3개 팔레트 제안**

#### Option A: Desert Horizon (사막 지평선)

앱의 warm desert 톤에 가장 충실한 팔레트.

| 탭 | 컬러명 | Hue | RGB (Light) | RGB (Dark) | 느낌 |
|----|--------|-----|-------------|------------|------|
| **Today** | Amber Gold | 30° | (0.79, 0.58, 0.42) | 유지 | 따뜻한 태양 |
| **Train** | Desert Coral | 15° | (0.85, 0.45, 0.38) | (0.92, 0.52, 0.45) | 테라코타/열정 |
| **Wellness** | Oasis Teal | 175° | (0.32, 0.68, 0.65) | (0.40, 0.76, 0.73) | 오아시스/회복 |

- Hue 간격: Today(30°) → Train(15°) → Wellness(175°) = **충분한 분리**
- 장점: 사막 테마 강화, warm+cool 대비
- 단점: Train이 Today와 warm 계열에서 가까울 수 있음

#### Option B: Warm Spectrum (따뜻한 스펙트럼)

모든 컬러가 warm 계열이되 확실한 분리.

| 탭 | 컬러명 | Hue | RGB (Light) | RGB (Dark) | 느낌 |
|----|--------|-----|-------------|------------|------|
| **Today** | Amber Gold | 30° | (0.79, 0.58, 0.42) | 유지 | 태양 |
| **Train** | Burnt Sienna | 12° | (0.80, 0.40, 0.33) | (0.88, 0.48, 0.40) | 불/에너지 |
| **Wellness** | Sage Mist | 140° | (0.45, 0.66, 0.48) | (0.53, 0.74, 0.56) | 세이지/자연 |

- Hue 간격: Today(30°) → Train(12°) → Wellness(140°) = **중간 분리**
- 장점: warm 톤 일관성
- 단점: Wellness가 기존 Activity 녹색과 유사할 수 있음

#### Option C: Contrast Harmony (대비 조화) — 추천

가장 확실한 시각적 분리. warm 브랜드 + 보색 활용.

| 탭 | 컬러명 | Hue | RGB (Light) | RGB (Dark) | 느낌 |
|----|--------|-----|-------------|------------|------|
| **Today** | Amber Gold | 30° | (0.79, 0.58, 0.42) | 유지 | 따뜻한 태양 |
| **Train** | Vivid Coral | 8° | (0.88, 0.42, 0.36) | (0.95, 0.50, 0.44) | 심장/활력 |
| **Wellness** | Soft Indigo | 230° | (0.45, 0.48, 0.72) | (0.55, 0.58, 0.80) | 평온/명상 |

- Hue 간격: Today(30°) → Train(8°) → Wellness(230°) = **매우 강한 분리**
- 장점: 3컬러가 완전히 다른 영역, 즉시 구분 가능
- 단점: Indigo가 기존 warm desert 톤과 다소 이질적일 수 있음

### Detail 화면 컬러 정책 (Phase 2에서 구현)

**혼합 정책**: 메트릭 고유 컬러 > 부모 탭 컬러

```
MetricDetailView(metric: .hrv)     → DS.Color.hrv (메트릭 고유)
MetricDetailView(metric: .sleep)   → DS.Color.sleep (메트릭 고유)
TrainingReadinessDetailView        → Train 탭 컬러 (메트릭 컬러 없음)
WeeklyStatsDetailView              → Train 탭 컬러 (메트릭 컬러 없음)
BodyHistoryDetailView              → Wellness 탭 컬러 (메트릭 컬러 없음)
ConditionScoreDetailView           → Today 탭 컬러
ExerciseSessionDetailView          → Train 탭 컬러
InjuryHistoryView                  → DS.Color.caution (부상 전용)
```

구현: `HealthMetric`에 `.waveColor` computed property 추가 — 없으면 Environment의 `tabWaveColor` fallback.

## Constraints

- **성능**: WaveShape는 pre-compute 120 sample points로 최적화됨. 이중 레이어 시 240 points — 문제 없음
- **접근성**: `reduceMotion` 존중 이미 구현됨
- **Watch**: WaveShape를 shared file로 추가 시 watchOS 타겟에 포함 필요 (xcodegen `sources` 설정)
- **Asset Catalog**: 새 컬러 추가 시 iOS + Watch 양쪽 Assets에 동기 (Correction #138)
- **기존 metric 컬러**: `DS.Color.activity`, `DS.Color.fitness`는 차트/배지에서 계속 사용. 웨이브 컬러는 별도 토큰
- **Correction #120**: dark variant 불필요 시 universal만 유지

## Edge Cases

- **iPad Multitasking**: sidebarAdaptable에서 탭 전환 시 웨이브 컬러 전환 — `.animation(.default)` 추가
- **데이터 없는 화면**: EmptyStateView에도 웨이브 유지 (배경 장식이므로 데이터 의존성 없음)
- **Sheet dismiss 후 색상 전환**: sheet의 웨이브와 부모의 웨이브 색상이 다를 경우 — sheet은 modal이므로 전환 없음
- **Watch 작은 화면**: amplitude가 너무 크면 콘텐츠 가독성 저하 — 0.03 이하로 제한

## Scope

### Phase 1 (Push 1): 웨이브 확산 + 파라미터 차별화
- TabWaveBackground 파라미터 탭별 분리
- Train 탭 이중 레이어 웨이브 추가
- Environment key로 컬러 전파 구조 구축
- Detail/Sheet/Watch 화면에 웨이브 적용
- DS.Gradient에 탭별 wave preset 토큰 추가

### Phase 2 (Push 2): 탭 아이덴티티 컬러 재정의
- 3개 팔레트 중 선택 후 Asset Catalog 색상 추가
- DS.Color에 탭 전용 웨이브 컬러 토큰 추가
- Detail 화면 메트릭별 웨이브 컬러 매핑
- Watch DS 동기화 (Correction #138)
- 기존 `DS.Color.activity`/`DS.Color.fitness`는 차트용으로 유지 (breaking change 방지)

### Future (추후)
- 웨이브 amplitude를 스크롤 위치에 연동 (parallax 효과)
- 사용자 커스텀 키컬러 선택
- iOS ↔ Watch shared Swift package로 DS 통합

## Decisions

1. **팔레트**: Option A (Desert Horizon) 확정
   - Today: Amber Gold (0.79, 0.58, 0.42)
   - Train: Desert Coral (0.85, 0.45, 0.38) / dark (0.92, 0.52, 0.45)
   - Wellness: Oasis Teal (0.32, 0.68, 0.65) / dark (0.40, 0.76, 0.73)
2. **Sheet 웨이브**: 모든 sheet에 적용
3. **Injury 화면 컬러**: 부상 전용 (`DS.Color.caution`)
4. **Train 이중 레이어**: 구현 후 시각적으로 과하면 조절

## Next Steps

- [ ] `/plan wave-expansion` 으로 Phase 1 구현 계획 생성 (웨이브 확산 + 파라미터 차별화)
- [ ] `/plan tab-identity-colors` 로 Phase 2 구현 계획 생성 (Desert Horizon 팔레트 적용)
