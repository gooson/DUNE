---
tags: [cardio, ios, gps, live-tracking, healthkit, clocationmanager, exercises-json]
date: 2026-03-02
category: brainstorm
status: draft
---

# Brainstorm: iOS 유산소 실시간 추적 (Watch 수준)

## Problem Statement

Watch에서는 유산소 운동 시 실시간 거리/페이스/HR/칼로리를 자동 추적하지만, iOS에서는 운동 후 수동 입력만 가능.
추가로 exercises.json에 `cardioSecondaryUnit` 필드가 아직 설정되지 않아 모든 유산소가 "km" 단위로 표시됨.

**핵심 목표:**
1. exercises.json에 40개 cardio 운동 단위 설정 (이미 구현된 코드 활성화)
2. iOS 전용 CardioSessionView로 실시간 메트릭 표시
3. CLLocationManager로 GPS 기반 거리 자동 추적

## Target Users

- **러너/워커**: iPhone으로 러닝 시작 → 실시간 거리/페이스 확인 (Watch 미착용 시)
- **사이클리스트**: 장거리 GPS 추적 + 실시간 페이스
- **실내 운동자**: 타이머 + HR + 칼로리 (GPS 없이)
- **수영/줄넘기/스테어 클라이머**: 운동별 적절한 단위 (m/count/floors)

## Success Criteria

1. exercises.json 업데이트로 수영=m, 줄넘기=count, 스테어 클라이머=floors, 일립티컬=timeOnly 표시
2. iOS CardioSessionView에서 실시간 타이머/HR/칼로리 표시
3. 실외 운동 시 CLLocationManager GPS 거리 자동 추적
4. 실내 운동 시 타이머+HR만 (거리는 운동 종료 후 수동 입력 가능)
5. 기존 근력 운동 WorkoutSessionView에 영향 없음
6. Watch 기존 기능 유지

## Current State

### 완료된 항목 (exercises.json만 미적용)

| 항목 | 상태 |
|------|------|
| `CardioSecondaryUnit` enum | ✅ Domain + Presentation extension |
| `ExerciseDefinition.cardioSecondaryUnit` | ✅ 필드 존재 |
| `CustomExercise` 지원 | ✅ |
| `SetRowView` 단위 분기 | ✅ |
| `WorkoutSessionView` stepper 분기 | ✅ |
| `WorkoutSessionViewModel` validation/변환 | ✅ |
| `CompoundWorkoutView` 헤더 분기 | ✅ |
| `CreateCustomExerciseView` Picker | ✅ |
| 테스트 (CardioSecondaryUnitTests) | ✅ |
| **exercises.json 단위 설정** | **❌ 0/40** |

### Watch 카디오 (완료)

| 항목 | 상태 |
|------|------|
| `WorkoutMode.cardio` | ✅ |
| `CardioMetricsView` | ✅ 거리/페이스/HR/칼로리 실시간 |
| `CardioStartView` (indoor/outdoor) | ✅ |
| 3초 카운트다운 | ✅ |
| Pause/Resume/End | ✅ |
| HKLiveWorkoutBuilder 거리 수집 | ✅ |
| HKWorkout 저장 (거리 포함) | ✅ |

### iOS 카디오 (미구현)

| 항목 | 상태 |
|------|------|
| 전용 CardioSessionView | ❌ |
| 실시간 타이머 | ❌ |
| 실시간 HR | ❌ (HealthKit query 필요) |
| GPS 거리 추적 | ❌ (CLLocationManager 필요) |
| Indoor/Outdoor 토글 | ❌ |
| HKWorkout 저장 (카디오) | ❌ |

## Proposed Approach

### Part A: exercises.json 단위 설정 (Quick Win)

40개 cardio 운동에 `cardioSecondaryUnit` 필드 추가:

| 운동 그룹 (×4 변형) | 단위 |
|---------------------|------|
| running, walking, cycling, hiking, stationary-bike | `"km"` |
| swimming, rowing-machine | `"meters"` |
| stair-climber | `"floors"` |
| jump-rope | `"count"` |
| elliptical | `"none"` |

이것만으로 이미 구현된 SetRowView/WorkoutSessionView/CompoundWorkoutView가 올바른 단위를 표시함.

### Part B: iOS CardioSessionView (전용 화면)

Watch `CardioMetricsView`를 참고한 iOS 전용 카디오 세션 화면:

```
┌─────────────────────────────────────┐
│           🏃 Running                │
│          Outdoor                    │
│                                     │
│            12:34                    │  ← 경과 시간 (대형)
│                                     │
│      ┌──────────────────────┐       │
│      │   3.42 km            │       │  ← GPS 거리 (실외)
│      │   4:52 /km           │       │  ← 현재 페이스
│      └──────────────────────┘       │
│                                     │
│      ❤️ 156 bpm    🔥 245 kcal     │  ← HR + 칼로리
│                                     │
│  ┌─────────┐  ┌─────────────────┐   │
│  │ ⏸ Pause │  │    ⏹ End        │   │
│  └─────────┘  └─────────────────┘   │
└─────────────────────────────────────┘
```

**실내 운동 시 (GPS 없음):**
- 거리/페이스 섹션 숨김
- 타이머 + HR + 칼로리만 표시
- 운동 종료 후 거리 수동 입력 옵션

### Part C: CLLocationManager GPS 추적

**실외 운동 시:**
1. 위치 권한 요청 (`whenInUse`)
2. `CLLocationManager.startUpdatingLocation()`
3. 위치 변화로 누적 거리 계산
4. 실시간 페이스 = 경과 시간 / 거리(km)
5. 운동 종료 시 HKWorkout에 거리 저장

**거리 계산:**
```swift
// 이전 위치와 현재 위치의 CLLocation.distance(from:) 누적
var totalDistance: CLLocationDistance = 0
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations {
        if let last = lastLocation,
           location.horizontalAccuracy < 20 {  // 정확도 필터
            totalDistance += location.distance(from: last)
        }
        lastLocation = location
    }
}
```

### Part D: iOS HKWorkout 저장

카디오 세션 완료 시 HKWorkout 생성:
- `activityType`: 운동에 맞는 `HKWorkoutActivityType`
- `duration`: 경과 시간
- `totalDistance`: GPS 거리 (실외) 또는 nil (실내)
- `totalEnergyBurned`: 추정 칼로리
- `metadata`: indoor/outdoor 구분

### Part E: 카디오 시작 플로우

```
ExerciseLibrary → 카디오 운동 선택 → CardioStartSheet
                                      ├─ 🌳 Outdoor (GPS 거리)
                                      └─ 🏠 Indoor (시간만)
                                    → CardioSessionView
                                    → 운동 종료 → SessionSummaryView
                                      ├─ 거리 (auto 또는 수동 입력)
                                      ├─ 시간
                                      └─ 저장 (ExerciseRecord + HKWorkout)
```

## Constraints

### 기술적 제약

- **Domain 레이어**: `CLLocationManager`, `HealthKit` import 금지 → Data/Presentation 레이어에서 처리
- **위치 권한**: `NSLocationWhenInUseUsageDescription` Info.plist 필수
- **배터리**: 장시간 GPS 추적 시 배터리 소모 → `desiredAccuracy: kCLLocationAccuracyBest` + `distanceFilter: 10`
- **CloudKit 스키마**: WorkoutSet에 새 필드 추가 불가 → 기존 `distance` 필드 활용
- **iOS 26+**: HKWorkoutBuilder 사용 (HKWorkoutSession은 Watch 전용이 아님, iOS 17+부터 가능)

### UX 제약

- **기존 수동 기록 플로우 유지**: 카디오도 기존처럼 세트별 수동 입력 가능해야 함
- **Watch와의 관계**: Watch로 카디오 추적 중 iPhone에서도 세션 표시? → MVP에서는 독립
- **백그라운드 추적**: 앱이 백그라운드일 때 GPS 유지? → `allowsBackgroundLocationUpdates = true`

## Edge Cases

1. **GPS 신호 없음**: 터널, 실내에서 outdoor 시작 → "GPS 검색 중" 표시, 수동 입력 fallback
2. **위치 권한 거부**: outdoor 선택 불가, indoor만 사용 가능
3. **운동 중 앱 전환**: Background location 유지 → 복귀 시 거리 정상 누적
4. **앱 종료**: 미저장 세션 데이터 유실 → `onDisappear`에서 임시 저장 (Correction #Watch onDisappear 패턴)
5. **Watch + iPhone 동시 추적**: 충돌 방지 필요 → MVP에서는 각각 독립
6. **기존 데이터 호환**: exercises.json 변경 전 기록된 데이터 (distance=km)는 그대로 유지

## Scope

### MVP (Must-have)

**Part A — exercises.json:**
- [ ] 40개 cardio 운동에 `cardioSecondaryUnit` 필드 추가
- [ ] 빌드/테스트 검증

**Part B — CardioSessionView:**
- [ ] 실시간 타이머 (경과 시간 표시)
- [ ] 실시간 HR 표시 (HKHealthStore query)
- [ ] 추정 칼로리 표시
- [ ] Pause/Resume/End 컨트롤
- [ ] Indoor/Outdoor 선택 시트

**Part C — GPS 거리 추적:**
- [ ] CLLocationManager 래퍼 서비스 생성
- [ ] 실외 운동 시 실시간 거리/페이스 표시
- [ ] 위치 권한 요청 + 거부 시 fallback
- [ ] Info.plist 위치 사용 설명 추가

**Part D — HKWorkout 저장:**
- [ ] 카디오 세션 완료 시 HKWorkout 저장
- [ ] ExerciseRecord 생성 (기존 WorkoutSet 패턴)

**Part E — 통합:**
- [ ] 카디오 운동 시작 플로우 (ExerciseLibrary → CardioStart → Session)
- [ ] 세션 요약 화면 (거리/시간/칼로리)

### Nice-to-have (Future)

- [ ] HKWorkoutRouteBuilder로 GPS 루트 저장 (지도 표시)
- [ ] Watch + iPhone 세션 동기화
- [ ] 자동 일시정지 (정지 감지)
- [ ] 킬로미터/마일 랩 알림
- [ ] 목표 거리/시간 설정
- [ ] 인터벌 모드 (work/rest 자동 전환)
- [ ] 마일 단위 지원

## Open Questions

1. **카디오 세션에서도 세트 기록 필요?** — 인터벌 러닝 등에서 랩별 기록이 필요한지, 아니면 전체 세션 1건만?
2. **Watch + iPhone 동시 사용 시 충돌?** — 둘 다 HKWorkout을 저장하면 중복 가능성
3. **칼로리 추정 방식?** — HR 기반 vs MET 기반 vs HealthKit 위임

## Architecture Decision

### 카디오 세션 관리자

iOS에서 카디오 세션을 관리할 새 서비스:

```
Presentation/Exercise/CardioSession/
├── CardioSessionView.swift          — 전용 UI
├── CardioSessionViewModel.swift     — 세션 상태 관리
├── CardioStartSheet.swift           — Indoor/Outdoor 선택
└── CardioSessionSummaryView.swift   — 운동 요약

Domain/Services/
└── LocationTrackingServiceProtocol.swift — 위치 추적 인터페이스

Data/Location/
└── LocationTrackingService.swift    — CLLocationManager 래퍼
```

**Layer Boundaries 준수:**
- Domain: `LocationTrackingServiceProtocol` (protocol only, no CLLocation import)
- Data: `LocationTrackingService` (CLLocationManager 구현)
- Presentation: `CardioSessionViewModel` (protocol 의존, 테스트 가능)

## Related Documents

- `docs/brainstorms/2026-02-28-improve-cardio-logging.md` — CardioSecondaryUnit 설계
- `docs/brainstorms/2026-03-02-auto-distance-tracking.md` — Watch 카디오 자동 추적
- `docs/plans/2026-02-28-improve-cardio-logging.md` — CardioSecondaryUnit 구현 계획
- `docs/solutions/architecture/2026-02-28-cardio-secondary-unit-pattern.md` — 단위 패턴

## Next Steps

- [ ] `/plan ios-cardio-live-tracking` 으로 구현 계획 생성
