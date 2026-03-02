---
tags: [cardio, ios, gps, live-tracking, healthkit, clocationmanager]
date: 2026-03-02
category: plan
status: approved
---

# Plan: iOS 카디오 실시간 추적

## 요약

iOS에서 유산소 운동을 시작하면 실시간 타이머/심박/칼로리를 표시하고,
실외 운동 시 CLLocationManager로 GPS 거리/페이스를 자동 추적하는 전용 CardioSessionView를 추가한다.

## 아키텍처

### Layer Boundaries

```
Domain/
├── Services/
│   └── LocationTrackingServiceProtocol.swift  (protocol only)

Data/
├── Location/
│   └── LocationTrackingService.swift          (CLLocationManager 구현)

Presentation/
├── Exercise/
│   ├── CardioSession/
│   │   ├── CardioStartSheet.swift             (Indoor/Outdoor 선택)
│   │   ├── CardioSessionView.swift            (실시간 메트릭 UI)
│   │   ├── CardioSessionViewModel.swift       (세션 상태 관리)
│   │   └── CardioSessionSummaryView.swift     (완료 요약)
```

### Key Decisions

1. **ExerciseStartView에서 분기**: cardio 운동 감지 → CardioStartSheet
2. **CardioSessionViewModel**: 타이머, HR 스트리밍, 거리/페이스 관리
3. **LocationTrackingService**: CLLocationManager 래퍼 (Data 레이어)
4. **WorkoutWriteService 확장**: 거리 데이터 포함한 HKWorkout 저장
5. **HKWorkoutSession (iOS)**: iOS 17+ 지원. Live HR + calories 수집

## 구현 단계

### Commit 1: Domain Protocol + Data Service

**신규**: `Domain/Services/LocationTrackingServiceProtocol.swift`
- `LocationTrackingServiceProtocol`: start/stop/distance/pace

**신규**: `Data/Location/LocationTrackingService.swift`
- `CLLocationManager` 래퍼
- accuracy filter: `horizontalAccuracy < 20m`
- `distanceFilter: 10m` (배터리 절약)
- background location 미지원 (MVP)

**수정**: `WorkoutWriteService.swift`
- `WorkoutWriteInput`에 `totalDistanceMeters: Double?` 추가
- distance 샘플을 HKWorkoutBuilder에 추가

### Commit 2: CardioSessionViewModel

**신규**: `Presentation/Exercise/CardioSession/CardioSessionViewModel.swift`
- Timer (elapsed time)
- HKWorkoutSession + HKLiveWorkoutBuilder (iOS 17+) for HR/calories
- LocationTrackingService 의존 (outdoor 시)
- Pause/Resume/End
- `createExerciseRecord()` → ExerciseRecord 생성

### Commit 3: CardioStartSheet + CardioSessionView

**신규**: `CardioStartSheet.swift`
- Indoor/Outdoor 선택 UI
- 위치 권한 상태 표시

**신규**: `CardioSessionView.swift`
- Real-time timer, distance, pace, HR, calories
- Pause/Resume/End buttons
- Watch CardioMetricsView 스타일 참조

### Commit 4: CardioSessionSummaryView + Integration

**신규**: `CardioSessionSummaryView.swift`
- 거리, 시간, 페이스, 칼로리 요약
- ExerciseRecord 저장 + HKWorkout 쓰기

**수정**: `ExerciseStartView.swift`
- cardio 운동 감지 → CardioStartSheet로 분기

### Commit 5: project.yml + 빌드 검증

**수정**: `DUNE/project.yml`
- 새 파일들 소스 경로 확인

**수정**: `Info.plist` (project.yml settings)
- `NSLocationWhenInUseUsageDescription` 추가

### Commit 6: Unit Tests

**신규**: `DUNETests/CardioSessionViewModelTests.swift`
- Timer start/pause/resume
- Distance calculation
- Pace calculation (distance=0 edge case)
- Record creation validation

### Commit 7: Localization

- xcstrings에 새 UI 문자열 ko/ja 추가

## Affected Files

| 파일 | 변경 | 커밋 |
|------|------|------|
| `Domain/Services/LocationTrackingServiceProtocol.swift` | **신규** | 1 |
| `Data/Location/LocationTrackingService.swift` | **신규** | 1 |
| `Data/HealthKit/WorkoutWriteService.swift` | distance 추가 | 1 |
| `Presentation/Exercise/CardioSession/CardioSessionViewModel.swift` | **신규** | 2 |
| `Presentation/Exercise/CardioSession/CardioStartSheet.swift` | **신규** | 3 |
| `Presentation/Exercise/CardioSession/CardioSessionView.swift` | **신규** | 3 |
| `Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | **신규** | 4 |
| `Presentation/Exercise/ExerciseStartView.swift` | cardio 분기 | 4 |
| `DUNE/project.yml` | 소스/설정 | 5 |
| `DUNETests/CardioSessionViewModelTests.swift` | **신규** | 6 |
| `DUNE/Resources/Localizable.xcstrings` | ko/ja 번역 | 7 |
