---
topic: iOS Cardio Live Tracking
date: 2026-03-02
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-28-cardio-secondary-unit-pattern.md
  - healthkit/2026-03-02-watch-cardio-distance-tracking.md
related_brainstorms:
  - 2026-03-02-auto-distance-tracking.md
  - 2026-02-28-improve-cardio-logging.md
---

# Implementation Plan: iOS Cardio Live Tracking

## Context

Watch에서 카디오 라이브 트래킹(거리/페이스/심박수/칼로리 실시간 표시)이 구현되었지만, iOS(iPhone)에서는 유산소 운동 시 여전히 **수동 입력**만 지원한다. 사용자가 iPhone만으로 러닝/사이클링 등 실외 운동을 시작하면 거리와 페이스가 자동 측정되지 않는다.

**목표**: iPhone에서 유산소 운동 시 CLLocationManager(GPS) 기반 실시간 거리/페이스 추적과 HKWorkoutSession 기반 칼로리/심박수 수집을 제공한다.

## Requirements

### Functional

1. 유산소 운동(durationDistance) 선택 시 Outdoor/Indoor 선택 UI 표시
2. Outdoor 선택 → CLLocationManager GPS 기반 실시간 거리/페이스 추적
3. Indoor 선택 → 타이머 기반 세션 (거리는 수동 입력 또는 CMPedometer 추정)
4. 실시간 메트릭 표시: 경과시간, 거리(km), 페이스(min/km), 심박수(bpm), 칼로리(kcal)
5. 일시정지/재개/종료 컨트롤
6. 워크아웃 종료 시 HKWorkout에 거리+칼로리 포함 저장
7. ExerciseRecord로 변환하여 SwiftData에 저장
8. 기존 수동 입력 워크플로우(WorkoutSessionView)에 영향 없음

### Non-functional

- Location 권한: 기존 `NSLocationWhenInUseUsageDescription` 활용 (이미 날씨용으로 설정됨)
- 배터리: GPS accuracy를 `kCLLocationAccuracyBest`로 설정하되, 실내에서는 사용 안 함
- Swift 6 호환: 모든 새 타입 Sendable 준수
- 레이어 경계: Domain에 HealthKit/CoreLocation import 금지

## Approach

**Watch 패턴 미러링**: Watch의 `WorkoutManager` + `CardioMetricsView` 아키텍처를 iPhone에 맞게 변환한다.

- **iOS CardioSessionManager**: CLLocationManager(GPS 거리) + HKWorkoutSession(칼로리/심박수) 조합
- **CardioSessionView**: Watch `CardioMetricsView`의 iPhone 확대판 (더 큰 화면에 맞는 레이아웃)
- **ExerciseStartView 확장**: isDistanceBased 운동일 때 Outdoor/Indoor 선택 → CardioSessionView 푸시

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| A. CLLocationManager + HKWorkoutSession | GPS 거리 정확, HK가 칼로리/HR 자동 수집, Watch 페어링 시 HR 수신 | CLLocationManager 관리 코드 필요 | **선택** — 가장 완전한 사용자 경험 |
| B. HKWorkoutSession만 (iOS 17+) | 코드 단순, Watch 구현과 동일 | iPhone GPS 거리는 HK가 자동 수집하지 않음 → 거리 없는 세션 | 거부 — 핵심 기능(거리) 누락 |
| C. CMPedometer만 | 권한 추가 불필요 | 러닝/워킹만 지원, 사이클링 불가, 정확도 낮음 | 거부 — 범용성 부족 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Data/HealthKit/CardioSessionManager.swift` | **NEW** | GPS 거리 + HKWorkoutSession 관리 |
| `Presentation/Exercise/CardioSessionView.swift` | **NEW** | 실시간 카디오 메트릭 UI |
| `Presentation/Exercise/CardioSessionViewModel.swift` | **NEW** | 세션 상태 관리, ExerciseRecord 생성 |
| `Presentation/Exercise/ExerciseStartView.swift` | MODIFY | isDistanceBased일 때 Outdoor/Indoor 선택 분기 |
| `Data/HealthKit/WorkoutWriteService.swift` | MODIFY | 거리 데이터 포함 HKWorkout 저장 |
| `DUNE/project.yml` | MODIFY | 새 파일 추가 (xcodegen) |
| `Resources/Localizable.xcstrings` | MODIFY | 새 UI 문자열 3개 언어 추가 |
| `DUNETests/CardioSessionManagerTests.swift` | **NEW** | 거리 계산, 페이스 포맷, 상태 전환 테스트 |
| `DUNETests/CardioSessionViewModelTests.swift` | **NEW** | 레코드 생성, 검증 로직 테스트 |

## Implementation Steps

### Step 1: CardioSessionManager — GPS 거리 추적 + HKWorkoutSession

- **Files**: `DUNE/Data/HealthKit/CardioSessionManager.swift` (NEW)
- **Changes**:
  - `@Observable @MainActor final class CardioSessionManager: NSObject`
  - CLLocationManager: `kCLLocationAccuracyBest`, `distanceFilter: 5` (5m마다 업데이트)
  - `distance: Double` (meters), `currentPace: Double` (sec/km), `elapsedTime: TimeInterval`
  - HKWorkoutSession: iOS 17+ API로 칼로리/심박수 수집 (Watch 페어링 시)
  - `startSession(activityType:isOutdoor:)`, `pause()`, `resume()`, `end()` lifecycle
  - Outdoor: CLLocationManager 시작 → `didUpdateLocations`에서 거리 누적
  - Indoor: GPS 미사용, 타이머만 동작
  - `formattedPace: String` computed ("M:SS" 형식, Watch 패턴과 동일)
  - `distanceKm: Double` computed (meters → km 변환)
  - Location 권한은 기존 `LocationService`와 별도 인스턴스 (`kCLLocationAccuracyBest`)
- **Verification**: `CardioSessionManagerTests` — 거리 계산, 페이스 계산, 상태 전환

### Step 2: CardioSessionViewModel — 세션 상태 관리 + 레코드 생성

- **Files**: `DUNE/Presentation/Exercise/CardioSessionViewModel.swift` (NEW)
- **Changes**:
  - `@Observable @MainActor final class CardioSessionViewModel`
  - `exercise: ExerciseDefinition`, `isOutdoor: Bool`, `sessionManager: CardioSessionManager`
  - `createValidatedRecord() -> ExerciseRecord?` — 세션 데이터로 ExerciseRecord 생성
    - distance: `sessionManager.distance / 1000.0` (meters → km)
    - duration: `sessionManager.elapsedTime` (seconds)
    - WorkoutSet 1개 생성 (전체 세션 = 1 set)
    - estimatedCalories: `sessionManager.activeCalories`
  - `startSession()`, `pauseSession()`, `resumeSession()`, `endSession()`
  - isSaving guard (중복 저장 방지)
- **Verification**: `CardioSessionViewModelTests` — 레코드 생성, duration 변환, 거리 변환

### Step 3: CardioSessionView — 실시간 메트릭 UI

- **Files**: `DUNE/Presentation/Exercise/CardioSessionView.swift` (NEW)
- **Changes**:
  - Watch `CardioMetricsView` 레이아웃을 iPhone 크기에 맞게 확대
  - `TimelineView(.periodic(from: .now, by: 1))` — 초 단위 업데이트
  - 상단: 운동 타입 아이콘 + 이름 + 경과 시간
  - 중앙: 거리 (대형 숫자, km)
  - 하단 격자: 페이스(/km) + 심박수(bpm) + 칼로리(kcal)
  - 바닥: Pause/Resume + End 버튼
  - End → confirmationDialog → WorkoutCompletionSheet 표시 후 dismiss
  - `DetailWaveBackground()` 배경
  - HealthKit write: `WorkoutWriteService` 경유 (거리 포함)
- **Verification**: 수동 확인 — iPhone 시뮬레이터에서 UI 렌더링

### Step 4: ExerciseStartView 확장 — Outdoor/Indoor 분기

- **Files**: `DUNE/Presentation/Exercise/ExerciseStartView.swift` (MODIFY)
- **Changes**:
  - `resolvedCardioType` computed property 추가 (Watch `WorkoutPreviewView` 패턴 재사용)
    - `WorkoutActivityType.resolveDistanceBased(from: exercise.id, name: exercise.name)`
  - isDistanceBased일 때: "Start Workout" 버튼 대신 "Outdoor" / "Indoor" 두 버튼 표시
  - Outdoor → `CardioSessionView(exercise:, isOutdoor: true)` 푸시
  - Indoor → `CardioSessionView(exercise:, isOutdoor: false)` 푸시
  - 비 isDistanceBased (elliptical, stair climber 등): 기존 `WorkoutSessionView` 유지
- **Verification**: ExerciseStartView에서 running/swimming → Outdoor/Indoor 표시, bench press → 기존 Start 표시

### Step 5: WorkoutWriteService 확장 — 거리 포함 HKWorkout 저장

- **Files**: `DUNE/Data/HealthKit/WorkoutWriteService.swift` (MODIFY)
- **Changes**:
  - `WorkoutWriteInput`에 `distanceKm: Double?` 필드 추가 (nil = 거리 없음)
  - `saveWorkout()`에서 distance가 있으면 `HKQuantitySample` 추가:
    - distanceWalkingRunning / distanceCycling / distanceSwimming (activityType에 따라)
  - `WorkoutWriteInput`에 `activityType: WorkoutActivityType?` 필드 추가 (거리 타입 결정용)
- **Verification**: `WorkoutWriteServiceTests` 업데이트 — 거리 포함 저장 케이스

### Step 6: Localization — 새 UI 문자열 추가

- **Files**: `DUNE/Resources/Localizable.xcstrings` (MODIFY)
- **Changes**:
  - "Outdoor" / "Indoor" (ExerciseStartView) — en/ko/ja
  - "End Workout" / "Save and finish this workout?" — 기존 키 재사용 가능
  - 필요 시 추가 문자열: "GPS Searching...", "Distance", "Pace" 등
- **Verification**: Xcode에서 3개 언어 커버리지 확인

### Step 7: 테스트 작성

- **Files**: `DUNETests/CardioSessionManagerTests.swift` (NEW), `DUNETests/CardioSessionViewModelTests.swift` (NEW)
- **Changes**:
  - **CardioSessionManagerTests**:
    - 거리 누적 계산 (CLLocation 배열 → 총 거리)
    - 페이스 계산 (distance / elapsed → sec/km)
    - formattedPace 출력 ("5:30", "--:--" for zero distance)
    - 상태 전환 (idle → running → paused → running → ended)
    - Indoor 모드에서 GPS 미사용 확인
  - **CardioSessionViewModelTests**:
    - createValidatedRecord — distance km 변환, duration 저장
    - isSaving guard 동작
    - exercise 속성 전달 (exerciseDefinitionID, primaryMuscles 등)
- **Verification**: `xcodebuild test -scheme DUNETests -only-testing DUNETests`

### Step 8: 빌드 검증 + xcodegen

- **Files**: `DUNE/project.yml` (필요 시), `scripts/build-ios.sh`
- **Changes**:
  - xcodegen은 파일 시스템 기반 자동 포함이므로 project.yml 변경 불필요할 수 있음
  - `scripts/build-ios.sh` 실행하여 빌드 통과 확인
- **Verification**: 빌드 성공, 경고 0

## Edge Cases

| Case | Handling |
|------|----------|
| GPS 신호 없음 (터널/실내) | 거리 0 유지, 페이스 "--:--" 표시. GPS 수신 재개 시 자동 업데이트 |
| Location 권한 거부 | Outdoor 버튼 탭 시 Settings 유도 alert. Indoor만 사용 가능 |
| 극단적 GPS 점프 (100m+ 순간 이동) | `CLLocation.horizontalAccuracy > 50` 이면 무시 |
| 운동 중 앱 백그라운드 진입 | HKWorkoutSession은 백그라운드에서 계속 동작, CLLocationManager는 `allowsBackgroundLocationUpdates = true` 필요 |
| 배터리 부족 | 시스템 레벨에서 관리 (GPS 정확도 자동 하향) |
| Watch 미페어링 | 심박수 수집 불가 → "--" 표시, 나머지 메트릭은 정상 |
| 0km 세션 저장 | 허용 (실내 러닝 등), distance=nil로 저장 |
| 일시정지 중 이동 | 일시정지 동안 CLLocationManager 업데이트 무시 |

## Testing Strategy

- **Unit tests**: CardioSessionManagerTests (거리/페이스 계산), CardioSessionViewModelTests (레코드 생성)
- **수동 검증**:
  - iPhone 시뮬레이터: UI 레이아웃, 상태 전환 (시뮬레이터에 GPS 시뮬레이션 가능)
  - 실기기: 실제 GPS 거리 추적, Watch 페어링 시 심박수 수신

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 백그라운드 GPS 권한 필요 | High | High | `UIBackgroundModes`에 `location` 추가, Info.plist 설명 문구 추가 |
| HKWorkoutSession iOS API 차이 | Medium | Medium | iOS 17+ API 확인 (Context7), Watch 코드 직접 복제 대신 적응 |
| 배터리 소모 우려 | Medium | Low | `distanceFilter: 5`로 업데이트 빈도 제한, 실내에서 GPS 미사용 |
| Location 권한 설명 문구 변경 | Low | Low | 기존 날씨용 문구를 운동 추적도 포함하도록 수정 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - Watch 구현이 검증된 아키텍처 참조점을 제공
  - CLLocationManager는 성숙한 API (iOS 2+)
  - HKWorkoutSession iOS 17+ 지원은 iOS 26 타겟에서 보장
  - 기존 코드(LocationService, WorkoutWriteService, WorkoutActivityType+HealthKit)를 재사용
  - 새 파일 위주 변경으로 기존 코드 영향 최소
