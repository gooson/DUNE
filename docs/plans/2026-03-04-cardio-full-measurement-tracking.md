---
tags: [cardio, walking, steps, pace, elevation, cadence, healthkit, coremotion, corelocation]
date: 2026-03-04
category: plan
status: draft
---

# Plan: 유산소 전체 실측 기록 강화 (iOS)

## 요약

`claude/hopeful-ritchie` 기반 iOS 카디오 세션에 `CMPedometer`를 통합해 걸음수/케이던스/고도/보행 페이스를 실측하고,
기존 GPS 거리와 결합해 세션 종료 시 `ExerciseRecord`와 HealthKit 워크아웃에 확장된 측정값을 저장한다.

핵심 정책:
- Outdoor 거리: GPS 우선, 실패 시 pedometer fallback
- 저장 실패 방지: 일부 지표가 없어도 세션 저장은 진행
- 예외 상황 최소 보장: 걸음수 중심 fallback 유지

## 아키텍처 결정

### 옵션 A 채택: Location + Motion 2-소스 병행 (채택)

- `LocationTrackingService`: GPS 거리 누적 (기존 유지)
- `MotionTrackingService`: 걸음수/케이던스/고도/보조 거리/보조 페이스
- `CardioSessionViewModel`: 두 소스를 통합해 표시/저장 값 결정

채택 이유:
1. 기존 GPS 정확도 필터 로직 재사용 가능
2. 권한/디바이스 실패 시 독립 fallback 경로 제공
3. 테스트 가능한 프로토콜 기반 DI 유지

## 구현 단계

### Phase 1: Motion 추적 계층 추가

1. `MotionTrackingServiceProtocol` (Domain) 추가
2. `MotionTrackingService` (Data) 추가
3. CMPedometer 실시간 업데이트 + 종료 시 최종 query 반영
4. 값 검증(음수/NaN/비정상 범위) 및 스레드 안전 저장

### Phase 2: Cardio 세션 ViewModel 확장

1. `CardioSessionRecord`에 step/pace/cadence/elevation 필드 추가
2. `CardioSessionViewModel`에 Motion 서비스 주입
3. start/pause/resume/end 라이프사이클에서 Motion 추적 제어
4. 거리 계산 정책 적용 (GPS 우선, fallback 허용)
5. 평균 페이스/케이던스 계산 및 저장 모델 생성

### Phase 3: UI/저장 확장

1. `CardioSessionView`에 라이브 걸음수/케이던스/고도 표시
2. `CardioSessionSummaryView`에 확장 지표 표시
3. `ExerciseRecord` 모델 필드 추가 및 저장 연결
4. `ExerciseSessionDetailView`에서 확장 지표 노출

### Phase 4: HealthKit write 확장

1. `WorkoutWriteInput` 확장 (stepCount, avgPace, cadence, elevation)
2. `WorkoutWriteService`에서 stepCount 샘플 추가
3. elevation/pace/cadence는 metadata 저장(지원 가능한 키 우선)
4. 기존 writer 호출부(`CardioSessionSummaryView`, `WorkoutHealthKitWriter`) 반영

### Phase 5: SwiftData schema & 테스트

1. `AppSchemaV8` 추가 + migration stage 업데이트
2. `CardioSessionViewModelTests` 확장 (fallback/기록값 검증)
3. 관련 컴파일 영향 테스트 수정
4. `scripts/test-unit.sh --no-regen` 또는 기본 `scripts/test-unit.sh`로 검증

## Affected Files

| 파일 | 변경 |
|------|------|
| `DUNE/Domain/Services/MotionTrackingServiceProtocol.swift` | 신규 Motion 추적 프로토콜 |
| `DUNE/Data/Motion/MotionTrackingService.swift` | 신규 CMPedometer 구현 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionViewModel.swift` | 실측 통합 로직 확장 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionView.swift` | 라이브 지표 UI 확장 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | 저장/요약 UI 확장 |
| `DUNE/Data/Persistence/Models/ExerciseRecord.swift` | step/pace/cadence/elevation 필드 추가 |
| `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift` | 저장 지표 표시 추가 |
| `DUNE/Data/HealthKit/WorkoutWriteService.swift` | step 샘플/metadata write 확장 |
| `DUNE/Presentation/Shared/WorkoutHealthKitWriter.swift` | 확장 input 전달 |
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | V8 schema + migration stage |
| `DUNE/project.yml` | CoreMotion.framework + NSMotionUsageDescription |
| `DUNETests/CardioSessionViewModelTests.swift` | 실측/저장 테스트 강화 |

## 검증 전략

1. 단위: CardioSessionViewModel에서 거리 우선순위, steps fallback, record 생성 값 검증
2. 통합: HealthKit write input 생성 경로 nil-safe 검증
3. 회귀: 기존 카디오 시작/종료 흐름, 저장 버튼 동작, 상세 화면 렌더 확인

## 위험 요소

1. CMPedometer 권한/가용성 기기 의존성
2. SwiftData schema 변경 영향 범위 확대 가능성
3. HealthKit metadata 키 지원 범위 차이로 일부 값 미저장 가능성

## 완료 조건

- 카디오 세션 저장 시 거리/걸음/페이스/케이던스/고도 중 가능한 값이 기록된다
- 권한 제약 상황에서도 세션이 저장되고 최소 걸음수 기록이 남는다
- 단위 테스트 통과 + 빌드/테스트 스크립트 통과
