---
tags: [watchos, cardio, ui-redesign, apple-fitness, heart-rate-zone, multi-page, workout-metrics]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: Watch 유산소 운동 UI — Apple Fitness 스타일 리디자인

## Problem Statement

현재 Watch 유산소 운동 화면(`CardioMetricsView`)은 **단일 페이지에 모든 메트릭 + 컨트롤**을 압축하여 표시한다.
Apple Fitness Watch 앱과 비교했을 때 다음 격차가 있다:

1. **정보 밀도 vs 가독성**: 작은 화면에 6개 메트릭 + 2개 버튼을 한 페이지에 넣어 숫자가 작고 읽기 어려움
2. **운동 종류별 최적화 부재**: 러닝/사이클/수영 모두 동일한 메트릭 세트 표시
3. **심박 존 미표시**: 유산소 강도 판단의 핵심 지표 누락
4. **컨트롤 혼재**: 메트릭 영역에 Pause/End 버튼이 공간을 차지

## Target Users

- 유산소 운동(러닝, 사이클, 수영 등)을 주로 하는 Apple Watch 사용자
- Apple Fitness 앱 UX에 익숙한 사용자
- 운동 중 핵심 메트릭을 **빠르게 확인**하고 싶은 사용자

## Success Criteria

1. Digital Crown으로 메트릭 페이지를 전환하는 다중 페이지 구조
2. 운동 종류별(러닝/사이클/수영/일반) 최적화된 메트릭 세트
3. 심박 존 실시간 표시 (Zone 1-5 색상 코딩)
4. 컨트롤(Pause/End)이 별도 페이지로 분리
5. Always-On Display 대응 (luminance reduced 모드)
6. 현재 대비 메트릭 숫자 크기 최소 1.5배 증가

## Apple Fitness Watch 앱 레퍼런스

### 페이지 구조 (러닝 기준)

```
Page 1 (Metrics)        Page 2 (HR Zone)       Page 3 (Segments)
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│  ELAPSED TIME    │   │  ❤️ 142          │   │  CURRENT SEGMENT │
│   23:45          │   │  ██████░░ Zone 3  │   │     1.00 km      │
│                  │   │  Cardio           │   │     5:12 /km     │
│  DISTANCE  PACE  │   │                  │   │                  │
│  4.52 km  5:15   │   │  In Zone 3       │   │  SEGMENTS        │
│                  │   │  12:30           │   │  #1  5:08  #2 5:22│
│  HR     CAL      │   │                  │   │                  │
│  142    312      │   │  Avg HR: 138     │   │  AVG PACE        │
│  bpm    kcal     │   │                  │   │    5:15 /km      │
└──────────────────┘   └──────────────────┘   └──────────────────┘

Page 4 (Controls)       Page 5 (NowPlaying)
┌──────────────────┐   ┌──────────────────┐
│                  │   │  🎵 NowPlaying   │
│   [ ⏸ Pause ]   │   │                  │
│                  │   │  Song Title      │
│   [ ⏹  End  ]   │   │  Artist          │
│                  │   │                  │
│   [ 💧 Lock ]   │   │  ◀️  ▶️  ▶▶     │
│                  │   │                  │
└──────────────────┘   └──────────────────┘
```

### 운동 종류별 메트릭 매핑

| 메트릭 | Running | Walking | Cycling | Swimming | HIIT/Generic |
|--------|---------|---------|---------|----------|-------------|
| Elapsed Time | ✅ | ✅ | ✅ | ✅ | ✅ |
| Distance | ✅ | ✅ | ✅ | ✅ (yards/m) | △ (가능시) |
| Pace (/km) | ✅ primary | ✅ primary | — | — | — |
| Speed (km/h) | — | — | ✅ primary | — | — |
| Heart Rate | ✅ | ✅ | ✅ | ✅ | ✅ |
| Calories | ✅ | ✅ | ✅ | ✅ | ✅ |
| Cadence (spm) | ✅ | ✅ | ✅ (rpm) | — | — |
| Elevation | △ | △ | ✅ | — | — |
| Laps | — | — | — | ✅ primary | — |
| Stroke Count | — | — | — | ✅ | — |
| Avg Pace/Speed | ✅ | ✅ | ✅ | — | — |
| HR Zone | ✅ | ✅ | ✅ | ✅ | ✅ |

△ = 센서/GPS 가용 시에만

### Apple Fitness 핵심 UX 패턴

1. **큰 숫자 우선**: primary 메트릭은 화면의 40-50% 차지
2. **2-row 레이아웃**: 한 페이지에 최대 4개 메트릭 (2x2 grid 또는 1+2 layout)
3. **색상 코딩**: HR=빨강, Distance=녹색, Calories=주황, Pace=파랑 계열
4. **HR Zone 바**: 수평 프로그레스 바 + Zone 번호 + Zone 이름
5. **Digital Crown**: 페이지 간 부드러운 전환
6. **Always-On**: 업데이트 주기 감소, 밝기 감소, 동일 레이아웃 유지
7. **Pause 제스처**: 사이드 버튼 + Digital Crown 동시 누르기로 Pause

## Proposed Approach

### Phase 1: 페이지 구조 재설계

**현재:**
```
SessionPagingView (vertical TabView)
├── Controls (Page 1)
├── CardioMetricsView — 모든 메트릭 + 컨트롤 (Page 2)
└── NowPlaying (Page 3)
```

**개선:**
```
SessionPagingView (vertical TabView)
├── CardioMainMetricsPage — primary 메트릭 2-4개 (Page 1, default)
├── CardioHRZonePage — 심박 존 + 실시간 HR (Page 2)
├── CardioSecondaryPage — 보조 메트릭 (Page 3) [운동별 다름]
├── ControlsView — Pause/End 전용 (Page 4)
└── NowPlayingView (Page 5)
```

### Phase 2: 운동 종류별 메트릭 프로파일

```swift
enum CardioMetricProfile {
    case running    // elapsed, distance, pace, hr, cal, cadence
    case cycling    // elapsed, distance, speed, hr, cal, elevation
    case swimming   // elapsed, laps, distance, hr, cal, stroke
    case generic    // elapsed, hr, cal, distance(optional)
}
```

각 프로파일이 Main/Secondary 페이지에 표시할 메트릭 배치를 결정.

### Phase 3: 심박 존 시스템

```
Zone 1 (< 60% maxHR): Recovery  — 회색/파랑
Zone 2 (60-70%):      Fat Burn  — 파랑
Zone 3 (70-80%):      Cardio    — 초록
Zone 4 (80-90%):      Hard      — 노랑/주황
Zone 5 (90%+):        Peak      — 빨강
```

- maxHR 계산: `220 - age` (HealthKit 생년월일 기반) 또는 사용자 직접 설정
- 실시간 Zone 표시 + Zone 내 체류 시간

### Phase 4: 메트릭 카드 디자인 시스템

```swift
// 재사용 메트릭 카드
struct WorkoutMetricCard: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    let size: MetricSize  // .large (primary) / .medium / .compact
}
```

**Large (primary):**
```
┌──────────────────────┐
│       23:45          │  ← .system(size: 48+, design: .rounded)
│     ELAPSED          │
└──────────────────────┘
```

**Medium (2-column grid):**
```
┌──────────┬──────────┐
│  4.52    │  5:15    │
│  km      │  /km     │
│ DISTANCE │  PACE    │
└──────────┴──────────┘
```

**Compact (3-column grid, 현재와 유사):**
```
┌───────┬───────┬───────┐
│  142  │  312  │  168  │
│  bpm  │  kcal │  spm  │
└───────┴───────┴───────┘
```

## 페이지별 레이아웃 (러닝 예시)

### Page 1: Main Metrics
```
┌──────────────────────┐
│     23:45            │  ← Elapsed (large, primary)
│                      │
│  4.52 km   5:15 /km  │  ← Distance + Pace (medium, 2-col)
│                      │
│  ❤️ 142    🔥 312    │  ← HR + Cal (compact, 2-col)
│   bpm       kcal     │
└──────────────────────┘
```

### Page 2: HR Zone
```
┌──────────────────────┐
│       ❤️              │
│      142             │  ← HR (large, zone color)
│       bpm            │
│                      │
│  ████████░░  Zone 3  │  ← Zone bar (5-segment)
│    Cardio            │  ← Zone name
│                      │
│  Zone 3: 12:30       │  ← Time in current zone
│  Avg HR: 138 bpm     │
└──────────────────────┘
```

### Page 3: Secondary (러닝)
```
┌──────────────────────┐
│    Current Pace      │
│      5:15 /km        │  ← Current pace (large)
│                      │
│  Avg Pace   Cadence  │
│  5:22 /km   168 spm  │  ← Average pace + Cadence (medium)
│                      │
│  Elevation Gain      │
│     +45 m            │
└──────────────────────┘
```

### Page 3: Secondary (사이클링)
```
┌──────────────────────┐
│    Current Speed     │
│     28.5 km/h        │  ← Speed (large)
│                      │
│  Avg Speed  Cadence  │
│  26.2 km/h  82 rpm   │
│                      │
│  Elevation Gain      │
│     +120 m           │
└──────────────────────┘
```

### Page 3: Secondary (수영)
```
┌──────────────────────┐
│       Laps           │
│        12            │  ← Lap count (large)
│                      │
│  Distance   Avg Pace │
│  600 m     2:05/100m │
│                      │
│  Stroke Rate         │
│    28 str/min        │
└──────────────────────┘
```

## Constraints

- **HealthKit 제약**: Cadence, Elevation, Stroke는 HK에서 제공하는 운동 타입에서만 사용 가능
- **maxHR 계산**: HealthKit 생년월일이 없으면 HR Zone 계산 불가 → fallback 필요 (수동 설정 또는 Zone 숨김)
- **watchOS 화면 크기**: 40mm/44mm/45mm/49mm Ultra 대응. 최소 40mm 기준 설계
- **Always-On Display**: luminance reduced 시 업데이트 주기 10초, 색상 dim
- **성능**: 5개 페이지 각각 TimelineView 사용 시 배터리 영향 고려
- **기존 SessionPagingView**: 근력 운동과 유산소 분기가 이미 존재 → 확장 구조
- **Correction #194**: pause 구간 제외한 active elapsed 기준 계산 유지

## Edge Cases

1. **HR 데이터 없음** (센서 미연결): HR Zone 페이지 전체를 숨기거나 "--" + 안내 표시
2. **GPS 없음** (실내 러닝): Distance/Pace를 보수적으로 표시하거나 "--"
3. **수영 Water Lock**: 화면 잠금 중 페이지 전환 불가 → Water Lock 해제 후 자동 메트릭 페이지 복귀
4. **초단시간 운동** (< 1분): 충분한 샘플 없이 평균값 계산 → "--" 표시
5. **maxHR 미설정**: Zone 계산 불가 → "Set max HR in Settings" 안내 또는 220-age 자동 추정
6. **luminance reduced**: 페이지 자동 전환 후 main metrics 페이지로 복귀
7. **Digital Crown 비활성화** (수영 중): 페이지 전환 불가 → 메인 페이지만 표시

## Scope

### MVP (Must-have)

- [ ] 다중 페이지 구조 (Main Metrics / HR Zone / Controls / NowPlaying)
- [ ] Main Metrics: Elapsed, Distance, Pace, HR, Calories (큰 숫자 레이아웃)
- [ ] HR Zone 페이지: 실시간 Zone 표시 + Zone 바 + Zone 이름
- [ ] Controls 별도 페이지 분리
- [ ] 러닝/사이클/일반 3개 프로파일 기본 지원
- [ ] Always-On Display 대응
- [ ] 재사용 메트릭 카드 컴포넌트

### Nice-to-have (Future)

- [ ] 수영 전용 프로파일 (Laps, Stroke, Water Lock 통합)
- [ ] Cadence (보폭수/페달 회전수) 표시
- [ ] Elevation gain 표시
- [ ] 구간 스플릿 (km별 pace 기록)
- [ ] Zone 체류 시간 히스토리 (막대 차트)
- [ ] 사용자 커스텀 메트릭 배치 설정
- [ ] Pace 알림 (목표 페이스 초과/미달 시 haptic)
- [ ] Live Activity 연동 (iPhone 잠금 화면)

## Open Questions

1. **maxHR 소스**: HealthKit 생년월일 자동 계산 vs 사용자 수동 입력 vs 양쪽 지원?
2. **Zone 색상**: Apple Fitness 5-Zone 색상을 그대로 사용할지, DS(Design System) 토큰으로 매핑할지?
3. **기본 페이지**: 앱 시작 시 Main Metrics가 기본인지, 사용자가 마지막 본 페이지를 기억할지?
4. **Cadence/Elevation**: HealthKit에서 실시간 제공 가능한 범위 확인 필요
5. **수영 모드**: watchOS Water Lock API 통합 범위 — MVP에서 제외해도 되는지?

## 기술적 고려사항

### HealthKit 데이터 소스 확장

현재 `WorkoutManager`가 수집하는 메트릭:
- Heart Rate, Active Calories, Distance

추가 필요:
- **Cadence**: `HKQuantityType(.runningStrideLength)` 또는 pedometer
- **Speed**: Distance / Time (계산) 또는 `HKQuantityType(.runningSpeed)`
- **Elevation**: `HKQuantityType(.flightsClimbed)` 또는 위치 기반
- **Swimming**: `HKQuantityType(.swimmingStrokeCount)`, lap 이벤트

### 페이지 성능

```swift
// 보이지 않는 페이지의 TimelineView 업데이트를 방지
TimelineView(.periodic(from: .now, by: isVisible ? 1 : 60)) { ... }
```

- 현재 보이는 페이지만 1초 업데이트, 나머지는 60초 (또는 정지)
- `@Environment(\.isLuminanceReduced)` 활용

### 파일 구조 (예상)

```
DUNEWatch/Views/Cardio/
├── CardioMainMetricsPage.swift      // Page 1: primary metrics
├── CardioHRZonePage.swift           // Page 2: HR zone display
├── CardioSecondaryMetricsPage.swift // Page 3: activity-specific
├── CardioMetricProfile.swift        // Activity → metric mapping
└── Components/
    ├── WorkoutMetricCard.swift      // Reusable metric display
    ├── HRZoneBar.swift              // Zone progress bar
    └── ZoneIndicator.swift          // Zone number + color
```

## Next Steps

- [ ] `/plan watch-cardio-fitness-style-ui` 로 구현 계획 생성
- [ ] HealthKit Cadence/Speed/Elevation 실시간 수집 가능 여부 검증
- [ ] HR Zone 색상을 DS 토큰으로 정의
- [ ] 기존 `CardioMetricsView` → 새 페이지 구조 마이그레이션 전략
