---
topic: watch-first-workout-ux
date: 2026-02-18
status: draft
confidence: medium
related_solutions:
  - architecture/2026-02-17-cloudkit-optional-relationship.md
  - architecture/2026-02-17-six-perspective-review-fixes.md
  - general/2026-02-17-second-review-validation-hardening.md
  - general/2026-02-16-swift6-healthkit-build-fixes.md
  - performance/2026-02-15-healthkit-query-parallelization.md
related_brainstorms:
  - 2026-02-18-watch-first-workout-ux.md
---

# Implementation Plan: Watch-First Workout UX

## Context

Watch 앱이 iPhone에 완전 종속되어 있어, 헬스장에서 Watch만으로 운동하는 것이 불가능. 운동 시작은 iPhone에서만 가능하고, 멀티 운동 세션/Rest Timer/HR 모니터링이 없으며, 오프라인 시 데이터가 유실됨.

Watch-First 독립 앱으로 전환하여 Watch 단독으로 루틴 선택 → 운동 → 기록 → 동기화가 가능하도록 한다.

## Requirements

### Functional

1. Watch에서 루틴(`WorkoutTemplate`) 목록을 보고 선택하여 운동 시작
2. 멀티 운동 세션: 루틴 내 여러 운동을 순서대로 진행, 자동 전환
3. Set-Log-Rest 루프: Digital Crown(weight) + +/-(reps) → Complete(1탭) → Rest Timer → 햅틱 → 다음 세트
4. 자동 Rest Timer: 운동별 기본 시간, 원형 카운트다운, +30s/Skip, `.notification` 햅틱
5. 실시간 HR 모니터링: `HKWorkoutSession` + `HKLiveWorkoutBuilder`
6. 오프라인 저장: Watch SwiftData 로컬 → CloudKit 자동 동기화
7. 세션 요약: 총 시간, 총 볼륨, 세트 수, 평균/최대 HR
8. 3-Page TabView: Controls(좌) | Metrics(중) | Media(우)

### Non-functional

- Watch 배터리 소비 최소화: `TimelineSchedule` 기반 렌더링, AOD 시 10초 간격
- CloudKit 동기화 범위: 루틴 + 최근 30일 기록만 Watch에서 표시
- 크래시 복구: `HKHealthStore().recoverActiveWorkoutSession()`으로 운동 세션 복구
- Swift 6 strict concurrency 준수

## Approach

**HKWorkoutSession 중심 아키텍처**: `WKExtendedRuntimeSession`이 아닌 `HKWorkoutSession`을 사용. 운동 중 백그라운드 실행 유지 + HR 센서 활성화 + Move/Exercise 링 반영을 한 번에 해결.

**SwiftData + CloudKit 공유 모델**: iPhone과 동일한 `@Model`을 Watch 타겟에서도 사용. `ModelConfiguration`의 CloudKit 컨테이너를 공유하여 양방향 자동 동기화.

**WatchConnectivity는 실시간 최적화 레이어로 유지**: CloudKit이 primary sync, WC는 둘 다 활성 시 즉시 반영용.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| WC만으로 동기화 (현재) | 구현 간단 | iPhone 필수, 오프라인 데이터 유실 | **기각** |
| CloudKit만 사용 | 단순한 아키텍처 | 실시간 반영 느림 (수초~수분) | **기각** |
| **CloudKit + WC 하이브리드** | 오프라인 안전 + 실시간 반영 | 동기화 충돌 가능성 | **채택** |
| Watch 전용 경량 모델 | Watch 최적화 | 변환 레이어 필요, 유지보수 2배 | **기각** |

## Affected Files

### 신규 생성

| File | Description |
|------|-------------|
| `Shared/Models/` (디렉토리) | iPhone+Watch 공유 @Model 이동 |
| `DailveWatch/Managers/WorkoutManager.swift` | HKWorkoutSession + HKLiveWorkoutBuilder 관리 |
| `DailveWatch/Views/RoutineListView.swift` | 루틴 목록 (Watch 메인 화면) |
| `DailveWatch/Views/SessionPagingView.swift` | 3-Page TabView (Controls/Metrics/Media) |
| `DailveWatch/Views/MetricsView.swift` | 세트 입력 + HR 표시 |
| `DailveWatch/Views/ControlsView.swift` | Pause/Resume/End |
| `DailveWatch/Views/RestTimerView.swift` | 원형 카운트다운 Rest Timer |
| `DailveWatch/Views/SessionSummaryView.swift` | 운동 완료 요약 |
| `DailveWatch/DailveWatch.entitlements` | HealthKit + CloudKit 권한 |

### 수정

| File | Change Type | Description |
|------|-------------|-------------|
| `Dailve/project.yml` | 수정 | Watch 타겟에 SwiftData, CloudKit, entitlements 추가 |
| `DailveWatch/DailveWatchApp.swift` | 수정 | ModelContainer 설정 추가 |
| `DailveWatch/ContentView.swift` | 수정 | 루트 라우팅 변경 (RoutineList 기본) |
| `DailveWatch/WatchConnectivityManager.swift` | 수정 | 실시간 최적화 레이어로 역할 축소 |
| `DailveWatch/WorkoutIdleView.swift` | 삭제 | RoutineListView로 대체 |
| `DailveWatch/QuickStartView.swift` | 삭제 | 루틴 기반 플로우로 대체 |
| `DailveWatch/WorkoutActiveView.swift` | 삭제 | SessionPagingView로 대체 |
| `Dailve/Data/Persistence/Models/*.swift` | 이동 | Shared/ 로 이동하여 양 타겟 공유 |
| `Dailve/Data/Persistence/Migration/AppSchemaVersions.swift` | 수정 | V5 스키마 (restDurationDefault 필드) |
| `Dailve/App/DailveApp.swift` | 수정 | Shared 모델 경로 반영 |

## Implementation Steps

### Phase 1: 인프라 (SwiftData + CloudKit + HealthKit on Watch)

#### Step 1: 공유 모델 분리 + Watch 타겟 설정

- **Files**: `Dailve/project.yml`, `Shared/Models/`, `DailveWatch/DailveWatch.entitlements`
- **Changes**:
  1. `Dailve/Data/Persistence/Models/` 의 @Model 파일들을 `Shared/Models/`로 이동
  2. `project.yml`에서 iPhone + Watch 양쪽 타겟에 `Shared/` 소스 포함
  3. Watch 타겟에 `SwiftData.framework` 의존성 추가
  4. `DailveWatch.entitlements` 생성: `com.apple.developer.healthkit`, `com.apple.developer.icloud-services` (CloudKit), `com.apple.developer.icloud-container-identifiers` (`iCloud.com.raftel.dailve`)
  5. Watch `Info.plist`에 `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` 추가
- **Verification**: `xcodegen generate` 성공, Watch 타겟 빌드 성공

#### Step 2: Watch ModelContainer 설정

- **Files**: `DailveWatch/DailveWatchApp.swift`, `Shared/Models/AppSchemaVersions.swift`
- **Changes**:
  1. `DailveWatchApp`에 `ModelContainer` 설정 추가 (iPhone과 동일한 CloudKit 컨테이너)
  2. 스키마 V5: `ExerciseDefinition`에 `restDurationDefault: TimeInterval?` 추가 (운동별 Rest Timer)
  3. `WorkoutTemplate`의 `TemplateEntry`에 `restDuration: TimeInterval?` 추가
  4. iPhone 앱의 `DailveApp.swift`도 V5 스키마 반영
  5. Watch에서도 store file 삭제 fallback 적용
- **Verification**: Watch 시뮬레이터에서 앱 2회 실행 (CloudKit 스키마 검증), 크래시 없음

#### Step 3: WorkoutManager (HKWorkoutSession + HKLiveWorkoutBuilder)

- **Files**: `DailveWatch/Managers/WorkoutManager.swift`
- **Changes**:
  1. `@Observable @MainActor` 싱글턴
  2. `startWorkout(activityType:)`: `HKWorkoutConfiguration` → `HKWorkoutSession` → `HKLiveWorkoutBuilder` → `session.prepare()` → `session.startActivity()`
  3. `pause()`, `resume()`, `end()`
  4. `HKWorkoutSessionDelegate`: 상태 전환 관리, ended 시 `endCollection` + `finishWorkout`
  5. `HKLiveWorkoutBuilderDelegate`: `didCollectDataOf`에서 HR/calories 실시간 업데이트
  6. 크래시 복구: 앱 시작 시 `HKHealthStore().recoverActiveWorkoutSession()` 호출
  7. HR 값 범위 검증: 20-300 bpm guard
- **Verification**: Watch 시뮬레이터에서 운동 시작/일시정지/종료 테스트, HR 업데이트 확인

### Phase 2: 핵심 UX (루틴 선택 → 세션 → 요약)

#### Step 4: RoutineListView (Watch 메인 화면)

- **Files**: `DailveWatch/Views/RoutineListView.swift`, `DailveWatch/ContentView.swift`
- **Changes**:
  1. `@Query` 로 `WorkoutTemplate` 목록 조회 (SwiftData)
  2. 각 루틴: 이름 + 운동 수 + 예상 시간 표시
  3. 탭하면 `SessionPagingView`로 전환 (운동 세션 시작)
  4. `ContentView` 수정: `WorkoutManager.isActive` 기준으로 RoutineList ↔ SessionPaging 분기
  5. 빈 상태: "iPhone에서 루틴을 만들어주세요" 안내
- **Verification**: 루틴 목록 표시, 탭하여 세션 시작 전환

#### Step 5: SessionPagingView (3-Page TabView)

- **Files**: `DailveWatch/Views/SessionPagingView.swift`, `ControlsView.swift`, `MetricsView.swift`
- **Changes**:
  1. `TabView` with `.tabViewStyle(.page)`, 3페이지
  2. AOD 대응: `isLuminanceReduced` 시 페이지 인디케이터 숨김, 메트릭 뷰로 자동 전환
  3. **ControlsView**: End(확인 다이얼로그) + Pause/Resume + Skip Exercise
  4. **MetricsView**: 운동명 + "Set N/Total" + Weight(Digital Crown) + Reps(+/-) + Complete 버튼 + HR 하단 표시
  5. 3번째 페이지: `NowPlayingView()` (시스템 미디어 컨트롤)
  6. `TimelineSchedule` 기반 렌더링: active 시 1초, AOD 시 10초 간격
- **Verification**: 3페이지 스와이프, AOD 전환, 메트릭 업데이트

#### Step 6: RestTimerView (자동 Rest Timer)

- **Files**: `DailveWatch/Views/RestTimerView.swift`
- **Changes**:
  1. 세트 완료 시 자동 표시 (MetricsView 위에 overlay 또는 전환)
  2. 원형 `Gauge` 카운트다운 (운동별 `restDuration` 사용, 기본 60초)
  3. 남은 시간 대형 숫자 (중앙)
  4. +30s / Skip 버튼
  5. 완료 시: `.notification` 햅틱 (`WKInterfaceDevice.current().play(.notification)`)
  6. 완료 후 자동으로 다음 세트의 MetricsView로 전환
  7. HR 표시 유지 (Rest 중에도)
- **Verification**: 세트 완료 → Rest Timer 자동 시작 → 카운트다운 → 햅틱 → 다음 세트

#### Step 7: 운동 전환 + 세션 요약

- **Files**: `DailveWatch/Views/MetricsView.swift`, `SessionSummaryView.swift`
- **Changes**:
  1. 모든 세트 완료 → "Next: [운동명]" 3초 표시 → 자동 전환
  2. 세션 진행률 바 (상단, 전체 운동 대비 현재 위치)
  3. 마지막 운동 완료 → `WorkoutManager.end()` → `SessionSummaryView`
  4. **SessionSummaryView**: 총 시간, 총 볼륨(kg), 총 세트 수, 평균/최대 HR
  5. "Done" 버튼 → SwiftData에 `ExerciseRecord` + `WorkoutSet` 저장 → RoutineListView 복귀
- **Verification**: 전체 루틴 플로우 (3운동 × 3세트) 완주 테스트

### Phase 3: 데이터 동기화 + 안정화

#### Step 8: SwiftData 저장 + CloudKit 동기화

- **Files**: `DailveWatch/Managers/WorkoutManager.swift`, `DailveWatchApp.swift`
- **Changes**:
  1. 세션 완료 시 `modelContext.insert()` 로 `ExerciseRecord` + `WorkoutSet` 저장
  2. CloudKit 자동 동기화 (ModelConfiguration에 CloudKit 컨테이너 설정)
  3. iPhone에서 Watch 저장 데이터 조회 가능 확인
  4. 동기화 범위: Watch에서는 `@Query` predicate로 최근 30일만 표시
- **Verification**: Watch에서 운동 완료 → iPhone Activity 탭에서 기록 확인

#### Step 9: WatchConnectivity 실시간 최적화

- **Files**: `DailveWatch/WatchConnectivityManager.swift`, `Dailve/Data/WatchConnectivity/WatchSessionManager.swift`
- **Changes**:
  1. Watch에서 운동 시작/완료 시 iPhone에 즉시 알림 (`sendMessage`)
  2. iPhone에서 루틴 편집 시 Watch에 즉시 반영 (`sendMessage` or `updateApplicationContext`)
  3. 기존 DTO 유지하되, 새 메시지 타입 추가: `"routineUpdated"`, `"workoutStarted"`, `"workoutEnded"`
  4. CloudKit 동기화 대기 시간(수초~수분) 동안의 갭을 WC로 보완
- **Verification**: iPhone에서 루틴 수정 → Watch에서 즉시 반영 확인

#### Step 10: 기존 Watch 뷰 정리 + 크래시 복구

- **Files**: 여러 DailveWatch 파일
- **Changes**:
  1. `WorkoutIdleView.swift`, `QuickStartView.swift`, `WorkoutActiveView.swift` 삭제
  2. 앱 시작 시 `recoverActiveWorkoutSession()` 호출 → 진행 중이던 세션 복구
  3. Watch 배터리 소진 → 재시작 시 SwiftData에서 미완료 세션 감지 → 요약 표시
- **Verification**: 운동 중 앱 강제 종료 → 재시작 시 세션 복구 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 빈 루틴 목록 (첫 사용) | "iPhone에서 루틴을 만들어주세요" 안내 + 아이콘 |
| 운동 중 Watch 배터리 소진 | SwiftData에 세트별 즉시 저장, 재시작 시 복구 |
| CloudKit 동기화 충돌 | last-writer-wins (SwiftData+CloudKit 기본 동작) |
| HR 센서 일시 실패 | "—" 표시, 자동 재시도, 기록에 gap |
| 운동 중 iPhone에서 같은 루틴 시작 | Watch 세션 우선, iPhone은 "Watch에서 진행 중" 표시 |
| Rest Timer 중 앱 백그라운드 | HKWorkoutSession이 백그라운드 유지, 타이머 계속 |
| AOD (Always On Display) | isLuminanceReduced 시 10초 간격 업데이트, 서브초 숨김 |
| 0세트 완료 후 End | 확인 다이얼로그 "기록 없이 종료하시겠습니까?" |

## Testing Strategy

### Unit Tests

- `WorkoutManagerTests`: 세션 시작/일시정지/종료 상태 전환
- `RestTimerTests`: 카운트다운 로직, +30s, skip, 완료 콜백
- `RoutineListViewModel`: 빈 상태, 정렬, 필터링
- `MetricsView` 로직: 세트 진행, 운동 전환, Weight/Reps 범위 검증

### Integration Tests

- SwiftData 저장 → 조회 일관성 (Watch 타겟)
- CloudKit 동기화: iPhone 저장 → Watch 조회 (실기기 필요)

### Manual Verification

- [ ] Watch 시뮬레이터: 루틴 선택 → 전체 세션 → 요약 플로우
- [ ] 실기기: HR 모니터링 정확도, 햅틱 강도
- [ ] AOD: 화면 내림 → 올림 시 올바른 렌더링
- [ ] 오프라인: iPhone 비행 모드 → Watch 운동 → iPhone 연결 후 동기화

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| CloudKit 스키마 충돌 (V5) | 중 | 높 | 2회 실행 테스트 필수, store 삭제 fallback |
| Watch 스토리지 부족 | 낮 | 중 | 30일 제한, predicate 필터링 |
| HR 업데이트 지연/누락 | 중 | 낮 | fallback "—" 표시, 배치 처리 대응 |
| HKWorkoutSession 크래시 복구 실패 | 낮 | 중 | SwiftData에 세트별 즉시 저장으로 데이터는 보존 |
| 공유 모델 이동 시 빌드 깨짐 | 중 | 중 | xcodegen 후 iPhone+Watch 양쪽 빌드 확인 |
| WC+CloudKit 이중 동기화 충돌 | 낮 | 중 | WC는 UI 즉시 반영용, CloudKit이 source of truth |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**:
  - 높음: SwiftData/CloudKit 패턴은 iPhone에서 검증됨, Watch UI는 Apple 표준 패턴 따름
  - 낮음: Watch CloudKit 동기화 실제 성능은 실기기 테스트 필요, HKWorkoutSession 크래시 복구 경험 부족
  - Phase 1-2는 시뮬레이터로 검증 가능, Phase 3은 실기기 필수
