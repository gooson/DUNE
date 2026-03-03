---
tags: [cardio, walking, coremotion, corelocation, healthkit, steps, cadence, elevation, pace]
date: 2026-03-04
category: solution
status: implemented
---

# iOS 카디오 실측 지표 통합 기록

## Problem

기존 iOS 카디오 세션은 GPS 거리와 MET 기반 칼로리 중심으로 동작하여,
고급 사용자가 원하는 실측 지표(걸음수, 케이던스, 고도 등)를 세션 기록에 충분히 남기지 못했다.

또한 권한/센서 제약(GPS 불가, 일부 센서 미가용) 상황에서 기록 일관성이 떨어질 수 있었다.

## Solution

### 1) 측정 소스 이중화

- `CoreLocation`: 실외 GPS 거리 + 고도 상승 누적
- `CoreMotion(CMPedometer)`: 걸음수, 케이던스, 층수, 보조 거리/페이스

`CardioSessionViewModel`에서 두 소스를 결합해 다음 정책으로 기록값을 결정한다.

- 거리: GPS 우선, 거리값 부재 시 pedometer distance fallback
- 고도: GPS elevation 우선, 없으면 floors 기반 보정치 사용
- 페이스: 거리+시간 평균 우선, 필요 시 pedometer average pace fallback

### 2) 저장 모델 확장

`ExerciseRecord`에 카디오 확장 필드를 추가했다.

- `stepCount`
- `averagePaceSecondsPerKm`
- `averageCadenceStepsPerMinute`
- `elevationGainMeters`
- `floorsAscended`

세션 요약 저장 시 위 필드를 모두 영속화한다.

### 3) HealthKit write 확장

`WorkoutWriteInput`/`WorkoutWriteService`를 확장해 다음을 반영했다.

- `HKQuantityType(.stepCount)` 샘플 저장
- `HKMetadataKeyElevationAscended` 저장
- pace/cadence 커스텀 metadata 저장

이후 `WorkoutQueryService`가 step/elevation을 읽을 수 있어 WorkoutSummary 품질이 개선된다.

### 4) UI 가시화

- 세션 진행 화면: steps/cadence/elevation/kcal 라이브 표시
- 세션 요약 화면: steps/cadence/elevation 포함
- 세션 상세 화면: 저장된 cardio metrics 별도 섹션 표시

## Prevention

1. `CMPedometerData`는 Sendable이 아니므로 continuation 경계 밖으로 직접 전달하지 않는다.
   - 서비스 내부에서 즉시 `MotionTrackingSnapshot`으로 변환 후 전달
2. 페이스 계산은 하한(>= 30 sec/km) 검증을 둬 초단기 세션의 비정상 값을 차단한다.
3. GPS-only/모션-only 단일 소스 가정 금지.
   - 거리/고도/페이스는 항상 fallback 경로를 둔다.
4. HealthKit write 시 steps/elevation은 샘플/메타데이터로 분리 저장해 쿼리 경로를 안정화한다.

## Files

| 파일 | 역할 |
|------|------|
| `Domain/Services/MotionTrackingServiceProtocol.swift` | 모션 추적 추상화 |
| `Data/Motion/MotionTrackingService.swift` | CMPedometer 구현 |
| `Presentation/Exercise/CardioSession/CardioSessionViewModel.swift` | 측정 소스 통합/기록 결정 |
| `Data/Persistence/Models/ExerciseRecord.swift` | 카디오 확장 필드 영속화 |
| `Data/HealthKit/WorkoutWriteService.swift` | steps/elevation/metadata HealthKit 저장 |
| `Presentation/Exercise/CardioSession/CardioSessionView.swift` | 라이브 지표 UI |
| `Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | 요약/저장 확장 |
| `Presentation/Exercise/ExerciseSessionDetailView.swift` | 상세 지표 표시 |
| `DUNETests/CardioSessionViewModelTests.swift` | fallback/저장 로직 검증 |
