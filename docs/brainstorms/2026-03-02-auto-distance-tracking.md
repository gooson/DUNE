---
tags: [cardio, distance, gps, watch, healthkit, workout-session, live-tracking]
date: 2026-03-02
category: brainstorm
status: draft
---

# Brainstorm: 유산소 거리 자동 추적 (Auto Distance Tracking)

## Problem Statement

현재 앱은 유산소 운동(러닝, 걷기 등) 시 **거리를 수동 입력**해야 하며, 실시간 GPS 기반 자동 거리 추적이 없음.
Apple 워크아웃 앱이나 Nike Running 앱처럼 **운동 시작 즉시 거리 측정이 자동으로 시작**되는 경험이 필요.

**현재 상태:**

| 영역 | 현재 | 목표 |
|------|------|------|
| Watch WorkoutManager | `activityType = .traditionalStrengthTraining` 고정 | 운동 종류에 맞는 `activityType` 동적 설정 |
| 거리 수집 | 없음 | `HKLiveWorkoutBuilder`가 자동 수집 |
| 페이스 계산 | 없음 (수동 입력 기반) | 실시간 distance / elapsed time |
| Watch 메트릭 UI | weight × reps (근력 전용) | 거리 + 페이스 + 심박수 + 칼로리 (카디오 전용) |
| HealthKit 저장 | 칼로리만 | 칼로리 + 거리 + 루트(GPS) |
| iPhone 카디오 | 수동 거리 입력 | Phase 2: CLLocationManager 기반 실시간 추적 |

## Target Users

- **러너/워커**: 가장 큰 사용자 그룹. Watch로 즉시 러닝 시작 → 거리/페이스 실시간 확인
- **사이클리스트/하이커**: 장거리 GPS 추적 필요
- **수영/로잉/일립티컬**: isDistanceBased 운동 중 비GPS 종목 (센서 기반 거리)
- **기존 근력 사용자**: 카디오 세션에서도 끊김 없는 UX 기대

## Success Criteria

1. Watch에서 isDistanceBased 운동 선택 → 3초 카운트다운 → 실시간 거리(km)/페이스(min/km)/심박수/칼로리 표시
2. HKLiveWorkoutBuilder가 올바른 `HKWorkoutActivityType`으로 거리 데이터 자동 수집
3. 워크아웃 종료 시 HealthKit에 거리 포함된 `HKWorkout` 저장
4. 기존 근력 운동 워크플로우(weight × reps)에 영향 없음
5. Outdoor 운동은 GPS 거리, Indoor 운동은 센서(가속도계) 거리 사용

## Current Architecture Analysis

### WorkoutManager.startSession() — 변경 필요 지점

```swift
// 현재: 항상 strength training
let config = HKWorkoutConfiguration()
config.activityType = .traditionalStrengthTraining  // ← 동적으로 변경 필요
config.locationType = .indoor                        // ← outdoor/indoor 분기 필요
```

### HKLiveWorkoutBuilderDelegate — 거리 수집 추가 필요

```swift
// 현재: heartRate + activeEnergyBurned만 처리
case HKQuantityType(.heartRate): ...
case HKQuantityType(.activeEnergyBurned): ...
// 추가 필요:
case HKQuantityType(.distanceWalkingRunning): ...
case HKQuantityType(.distanceCycling): ...
case HKQuantityType(.distanceSwimming): ...
```

### Watch 메트릭 UI — 카디오 전용 뷰 필요

현재 `MetricsView`는 weight × reps 입력 전용. 카디오 운동에서는:
- 거리 (km, 대형 숫자)
- 현재 페이스 (min/km)
- 경과 시간
- 심박수 + 칼로리

### WatchExerciseInfo — 이미 cardioSecondaryUnit 필드 존재

```swift
struct WatchExerciseInfo: Codable, Sendable, Hashable {
    let cardioSecondaryUnit: String?  // ← 이미 전달됨, 활용만 하면 됨
}
```

## Proposed Approach

### Phase 1: Watch 카디오 라이브 트래킹 (MVP)

#### 1-A. WorkoutManager 확장

**HKWorkoutConfiguration 동적 설정:**

```swift
func startCardioSession(
    activityType: WorkoutActivityType,
    isOutdoor: Bool
) async throws {
    let config = HKWorkoutConfiguration()
    config.activityType = activityType.hkActivityType  // Domain → HK 매핑
    config.locationType = isOutdoor ? .outdoor : .indoor

    // ... 기존 세션 시작 로직
}
```

**거리 메트릭 수집:**

```swift
// WorkoutManager에 추가
private(set) var distance: Double = 0       // meters
private(set) var currentPace: Double = 0    // seconds per km

// HKLiveWorkoutBuilderDelegate에서
case HKQuantityType(.distanceWalkingRunning),
     HKQuantityType(.distanceCycling),
     HKQuantityType(.distanceSwimming):
    let meters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
    distance = meters
    if meters > 0, let elapsed = startDate?.timeIntervalSinceNow {
        currentPace = abs(elapsed) / (meters / 1000)  // sec/km
    }
```

**HealthKit Authorization 확장:**

```swift
let readTypes: Set<HKObjectType> = [
    HKQuantityType(.heartRate),
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.distanceWalkingRunning),  // 추가
    HKQuantityType(.distanceCycling),          // 추가
    HKQuantityType(.distanceSwimming),         // 추가
]
```

#### 1-B. 카디오 메트릭 뷰 (CardioMetricsView)

Apple 워크아웃 앱 스타일의 실시간 메트릭 화면:

```
┌─────────────────────────┐
│     🏃 Running          │  ← 운동 종류
│                         │
│      3.42               │  ← 거리 (km) — 대형 숫자
│       km                │
│                         │
│  5:12 /km    ❤️ 156     │  ← 페이스 + 심박수
│  12:34       🔥 245     │  ← 경과시간 + 칼로리
│                         │
│  ⏸️ Pause    ⏹️ End     │  ← 컨트롤
└─────────────────────────┘
```

**기존 MetricsView와의 관계:**
- `MetricsView` = 근력 운동 전용 (weight × reps)
- `CardioMetricsView` = 카디오 운동 전용 (거리 + 페이스)
- `SessionPagingView`에서 운동 타입에 따라 분기

#### 1-C. 카디오 시작 플로우 (Watch)

현재 Watch 시작 플로우:
```
CarouselHomeView → 운동 선택 → WorkoutPreviewView → Start → MetricsView
```

카디오 분기 추가:
```
CarouselHomeView → 카디오 운동 선택 → CardioStartView (Outdoor/Indoor 선택)
                                      → 3초 카운트다운 → CardioMetricsView
```

**CardioStartView:**
```
┌─────────────────────────┐
│     🏃 Running          │
│                         │
│  ┌─────────────────┐    │
│  │  🌳 Outdoor     │    │  ← GPS 거리
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │  🏠 Indoor      │    │  ← 센서 거리
│  └─────────────────┘    │
│                         │
│  Open Goal (무제한)     │  ← MVP: 목표 설정 없음
└─────────────────────────┘
```

#### 1-D. WorkoutActivityType → HKWorkoutActivityType 매핑

Domain 레이어에 직접 HealthKit import 불가 → Data 레이어에 매핑 extension:

```swift
// Data/HealthKit/WorkoutActivityType+HK.swift
import HealthKit

extension WorkoutActivityType {
    var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .hiking: return .hiking
        case .elliptical: return .elliptical
        case .rowing: return .rowing
        // ... 모든 isDistanceBased 매핑
        default: return .traditionalStrengthTraining
        }
    }
}
```

**주의**: 이 매핑은 Watch 타겟에도 필요. 공유 파일 또는 Watch 내 별도 매핑.

#### 1-E. isDistanceBased 운동 분류와 HK Distance Type 매핑

| WorkoutActivityType | HKQuantityType | locationType |
|---------------------|---------------|-------------|
| running | .distanceWalkingRunning | outdoor/indoor |
| walking | .distanceWalkingRunning | outdoor/indoor |
| cycling | .distanceCycling | outdoor/indoor |
| swimming | .distanceSwimming | indoor (pool) |
| hiking | .distanceWalkingRunning | outdoor |
| elliptical | .distanceWalkingRunning | indoor |
| rowing | .distanceWalkingRunning | indoor |
| handCycling | .distanceWheelchair | outdoor/indoor |
| crossCountrySkiing | .distanceCrossCountrySkiing | outdoor |
| downhillSkiing | .distanceDownhillSnowSports | outdoor |
| paddleSports | .distancePaddleSports | outdoor |
| swimBikeRun | .distanceWalkingRunning | outdoor |

### Phase 2: iPhone CLLocationManager 기반 추적 (Future)

Watch 없이 iPhone만으로 러닝 시 CLLocationManager + GPS로 거리 추적.
Phase 1 완료 후 별도 brainstorm.

### Phase 3: 루트 기록 (Future)

`HKWorkoutRouteBuilder` + `CLLocationManager`로 GPS 루트를 HealthKit에 저장.
Apple 피트니스 앱에서 지도 위 루트 표시.

## Constraints

### 기술적 제약

1. **Domain 레이어 HealthKit 금지**: `WorkoutActivityType → HKWorkoutActivityType` 매핑은 Data/Watch 레이어에서만
2. **Watch 타겟 분리**: Watch WorkoutManager는 DUNEWatch 타겟에만 존재. iOS 타겟과 코드 공유 제한적
3. **CloudKit 스키마**: `WorkoutSet`에 새 필드 추가 불가 — 기존 `distance` 필드 활용
4. **WatchExerciseInfo 양쪽 동기화 (#69)**: Watch/iOS 양쪽 DTO 동시 업데이트 필수
5. **Swift 6 Sendable**: 새 struct는 `Sendable` 준수 필수

### HK 데이터 제약

1. **Indoor 거리 정확도**: GPS 없이 가속도계 기반 → 보정 필요 (Apple은 자동 보정)
2. **수영 거리**: Apple Watch가 자동 랩 감지. `HKLiveWorkoutBuilder`에 poolLength 설정 가능
3. **실시간 페이스**: `HKLiveWorkoutBuilder`는 cumulative distance만 제공 → 순간 페이스는 delta 계산 필요

### UX 제약

1. **Watch 화면 크기**: 4개 메트릭(거리+페이스+심박수+칼로리) 동시 표시 시 가독성 주의
2. **Always-On Display**: `isLuminanceReduced` 시 업데이트 빈도 감소 필요
3. **Digital Crown**: 카디오 뷰에서 Crown은 TabView 페이징에 사용 → 커스텀 인터랙션 불가

## Edge Cases

1. **GPS 신호 없음**: 터널, 실내에서 outdoor 러닝 시작 → 거리 0 표시, "GPS 검색 중" 상태
2. **Watch 배터리 부족**: 장시간 GPS 추적 시 배터리 소모 → Background mode 자동 관리 (HK 위임)
3. **앱 크래시 복구**: `recoverActiveWorkoutSession()`으로 카디오 세션도 복구 → 거리 누적값 유지됨 (HKLiveWorkoutBuilder가 시스템 레벨에서 관리)
4. **운동 중 일시정지**: 일시정지 중 이동 거리는 포함 안 됨 (HKWorkoutSession이 자동 처리)
5. **근력→카디오 혼합 템플릿**: 한 워크아웃 안에 스쿼트 + 러닝이 있으면? → MVP에서는 카디오 운동은 단독 세션만 지원. 혼합 템플릿에서 카디오 항목은 수동 입력 유지
6. **isDistanceBased인데 Watch 미착용**: iPhone에서 시작한 경우 → Phase 1에서는 수동 입력 유지, Phase 2에서 CLLocationManager 추가
7. **거리 단위**: km 고정 (앱 내 설정). mi 지원은 Future
8. **수영 자동 워크아웃 감지**: Apple Watch 수영 모드는 화면 잠금 + Water Lock 자동 활성화 → HKWorkoutConfiguration에 `.swimming` + `swimLocationType` 설정 필요

## Scope

### MVP (Must-have)

- [ ] WorkoutManager에 `distance`, `currentPace` 프로퍼티 추가
- [ ] HKWorkoutConfiguration을 운동 타입에 맞게 동적 설정 (activityType + locationType)
- [ ] HKLiveWorkoutBuilderDelegate에서 거리 데이터 수집 (distanceWalkingRunning, distanceCycling, distanceSwimming)
- [ ] HealthKit authorization에 거리 타입 추가
- [ ] CardioMetricsView: 거리(km) + 페이스(min/km) + 심박수(bpm) + 칼로리(kcal) 실시간 표시
- [ ] CardioStartView: Outdoor/Indoor 선택 + 3초 카운트다운
- [ ] SessionPagingView: 운동 타입(isDistanceBased)에 따라 MetricsView / CardioMetricsView 분기
- [ ] 모든 isDistanceBased 운동 지원 (12종)
- [ ] WorkoutActivityType → HKWorkoutActivityType 매핑 (Watch 타겟)
- [ ] 워크아웃 완료 시 거리 포함된 HKWorkout 저장 확인
- [ ] Pause/Resume/End 컨트롤
- [ ] 카디오 세션 크래시 복구 지원

### Nice-to-have (Future)

- [ ] iPhone CLLocationManager 기반 거리 추적 (Phase 2)
- [ ] HKWorkoutRouteBuilder로 GPS 루트 저장 (Phase 3)
- [ ] 목표 설정 (5K, 10K, 시간 목표)
- [ ] 마일 단위 지원
- [ ] 자동 일시정지 (정지 감지 시)
- [ ] 인터벌 모드 (work/rest 구간 자동 전환)
- [ ] 실시간 페이스 알림 (목표 페이스 벗어나면 haptic)
- [ ] 킬로미터/마일 랩 알림 (1km마다 haptic + 랩 타임 표시)
- [ ] Apple 피트니스 앱 연동 확인 (저장된 HKWorkout이 피트니스 앱에 정상 표시)

## Architecture Decision: 카디오 세션 vs 근력 세션

### 옵션 A: 단일 WorkoutManager + 모드 분기

```swift
enum WorkoutMode {
    case strength(template: WorkoutSessionTemplate)
    case cardio(activityType: WorkoutActivityType, isOutdoor: Bool)
}
```

**장점**: 기존 코드 최소 변경, 심박수/칼로리 수집 코드 재사용
**단점**: WorkoutManager가 비대해짐, 모드별 분기가 곳곳에 필요

### 옵션 B: CardioWorkoutManager 별도 생성

```swift
@Observable
final class CardioWorkoutManager: NSObject {
    // 카디오 전용 세션 관리
}
```

**장점**: 관심사 분리, 각 Manager가 단순
**단점**: HK 세션 관리/delegate 코드 중복, 앱 전체에서 두 Manager 참조 필요

### 권장: 옵션 A (단일 WorkoutManager + 모드 분기)

**근거**:
1. `HKWorkoutSession` / `HKLiveWorkoutBuilder` 관리 코드가 동일
2. 심박수, 칼로리 수집은 공통
3. Recovery 로직 공유 가능
4. WorkoutManager가 이미 singleton이므로 두 번째 singleton은 설계 복잡도 증가

## Open Questions

1. **혼합 템플릿**: 근력 + 카디오가 섞인 템플릿에서 카디오 항목의 UX는? (MVP에서는 수동 입력 유지?)
2. **Watch → iPhone 데이터 전달**: 카디오 세션 완료 시 `WatchWorkoutUpdate`에 거리 데이터 포함 방법
3. **수영 poolLength 설정 UI**: 수영 시작 전 풀 길이(25m/50m) 선택 UI 필요?
4. **Auto Pause**: Apple 워크아웃 앱처럼 정지 시 자동 일시정지? (HKWorkoutSession은 autoPause 지원)

## Related Documents

- `docs/brainstorms/2026-02-28-improve-cardio-logging.md` — 카디오 보조 단위 (Phase 1 완료됨)
- `docs/plans/2026-02-28-improve-cardio-logging.md` — CardioSecondaryUnit 구현 계획
- `docs/solutions/architecture/2026-02-28-cardio-secondary-unit-pattern.md` — 카디오 단위 패턴

## Next Steps

- [ ] `/plan auto-distance-tracking` 으로 구현 계획 생성
