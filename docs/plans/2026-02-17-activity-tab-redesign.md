---
topic: activity-tab-redesign
date: 2026-02-17
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-15-domain-layer-purity
  - architecture/2026-02-16-viewmodel-layer-boundary-enforcement
  - security/2026-02-15-input-validation-swiftdata
  - performance/2026-02-15-healthkit-query-parallelization
  - general/2026-02-17-chart-ux-layout-stability
related_brainstorms:
  - 2026-02-17-activity-tab-redesign
---

# Implementation Plan: Activity 탭 UX 전면 개편 (Phase 1)

## Context

현재 Activity 탭은 모든 운동을 동일한 폼(Duration + Calories + Distance + Memo)으로 기록한다. 근력 운동이 "Strength" 하나로 통합되어 있고, 세트/렙/무게 기록이 불가능하며, 이전 기록 참조·근육 그룹 추적·자동 칼로리 추정이 없다.

Phase 1은 **기록 인프라**에 집중한다: 운동 타입별 맞춤 입력, 100+ 운동 라이브러리, 이전 세션 인라인 표시, 휴식 타이머, MET 기반 칼로리 추정.

## Requirements

### Functional

- F1: 근력 운동은 세트 × 렙 × 무게(kg) 단위로 기록
- F2: 유산소 운동은 시간 + 거리 단위로 기록 (기존 유지)
- F3: 운동 선택 시 라이브러리에서 검색 (100+ 종, 근육 그룹/장비 분류)
- F4: 이전 동일 운동의 마지막 세션 기록을 인라인으로 표시
- F5: 세트 완료 시 휴식 타이머 자동 시작 (기본 90초, 운동별 커스텀)
- F6: HealthKit 칼로리 우선, 없으면 MET × 체중 × 시간으로 자동 추정
- F7: 각 운동에 주요/보조 근육 그룹 태깅 (라이브러리 기반 자동)
- F8: 최근 운동 목록에 세트 요약 표시 (예: "3세트 · 60-65kg · 26렙")
- F9: 바디웨이트 운동은 세트 × 렙 (무게 optional)
- F10: 기존 ExerciseRecord 데이터 하위 호환 유지

### Non-functional

- NF1: 1세트 기록에 3탭 이하 (무게 입력 → 렙 확인 → 체크)
- NF2: Swift 6 strict concurrency 준수
- NF3: SwiftData VersionedSchema 도입으로 안전한 마이그레이션
- NF4: CloudKit 호환 (새 필드는 optional 또는 default)
- NF5: 운동 라이브러리는 번들 JSON (SwiftData 아님)
- NF6: 레이어 경계 준수 (Domain에 SwiftUI 금지, ViewModel에 ModelContext 금지)

## Approach

**7단계 점진적 구현**: 각 Step이 독립적으로 빌드·테스트 가능하도록 설계. 모델 → 서비스 → UI 순서로 bottom-up 진행.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| A. 한 번에 전체 구현 | 빠름 | 리뷰 불가, 롤백 어려움 | 기각 |
| B. 운동별 별도 View | 타입 안전 | 코드 중복, 유지보수 난이도 | 기각 |
| **C. InputType 기반 동적 폼** | 확장 가능, DRY, 한 View로 모든 타입 | 조건 분기 복잡도 | **채택** |
| D. SwiftData 상속 (iOS 26) | 깔끔한 모델 분리 | iOS 26 신규 API, 검증 부족 | 기각 (Phase 2 재검토) |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| **신규: Domain 모델** | | |
| `Domain/Models/ExerciseDefinition.swift` | Create | 운동 라이브러리 정적 모델 (enum 포함) |
| `Domain/Models/MuscleGroup.swift` | Create | MuscleGroup enum |
| `Domain/Models/Equipment.swift` | Create | Equipment enum |
| `Domain/Models/ExerciseCategory.swift` | Create | ExerciseCategory, ExerciseInputType enum |
| `Domain/UseCases/CalorieEstimationService.swift` | Create | MET 기반 칼로리 추정 프로토콜 + 구현 |
| **신규: Data 레이어** | | |
| `Data/Persistence/Models/WorkoutSet.swift` | Create | @Model 세트별 데이터 |
| `Data/Persistence/Migration/AppSchemaVersions.swift` | Create | VersionedSchema V1 → V2 |
| `Data/Resources/exercises.json` | Create | 100+ 운동 라이브러리 JSON |
| `Data/ExerciseLibraryService.swift` | Create | JSON 로드 + 검색 서비스 |
| **신규: Presentation** | | |
| `Presentation/Exercise/WorkoutSessionView.swift` | Create | 운동 세션 메인 화면 (세트 입력) |
| `Presentation/Exercise/WorkoutSessionViewModel.swift` | Create | 세션 상태 관리, 이전 기록 로드 |
| `Presentation/Exercise/Components/SetRowView.swift` | Create | 개별 세트 입력 행 |
| `Presentation/Exercise/Components/ExercisePickerView.swift` | Create | 운동 라이브러리 검색/선택 |
| `Presentation/Exercise/Components/RestTimerView.swift` | Create | 휴식 타이머 오버레이 |
| `Presentation/Exercise/RestTimerViewModel.swift` | Create | 타이머 상태 관리 |
| `Presentation/Shared/Extensions/MuscleGroup+View.swift` | Create | 근육 그룹 색상/아이콘 |
| `Presentation/Shared/Extensions/Equipment+View.swift` | Create | 장비 아이콘 |
| **수정: 기존 파일** | | |
| `Data/Persistence/Models/ExerciseRecord.swift` | Modify | sets 관계, exerciseID, muscles, calorieSource 추가 |
| `App/DailveApp.swift` | Modify | ModelContainer에 WorkoutSet + Migration Plan 등록 |
| `Presentation/Activity/ActivityView.swift` | Modify | 새 운동 입력 플로우 연결, 세트 요약 표시 |
| `Presentation/Activity/Components/ExerciseListSection.swift` | Modify | 세트 요약 정보 표시 |
| `Presentation/Exercise/ExerciseView.swift` | Modify | 새 입력 플로우 연결, 중복 AddExerciseSheet 제거 |
| `Presentation/Exercise/ExerciseViewModel.swift` | Modify | ExerciseListItem에 세트 요약 추가 |
| **테스트** | | |
| `DailveTests/ExerciseDefinitionTests.swift` | Create | 라이브러리 로드, 검색, 분류 |
| `DailveTests/CalorieEstimationTests.swift` | Create | MET 계산, 경계값, NaN 방어 |
| `DailveTests/WorkoutSessionViewModelTests.swift` | Create | 세트 추가/삭제, 이전 기록, 유효성 |
| `DailveTests/RestTimerViewModelTests.swift` | Create | 타이머 시작/정지/리셋 |

## Implementation Steps

### Step 1: Domain 모델 및 Enum 정의

- **Files**: `Domain/Models/ExerciseDefinition.swift`, `MuscleGroup.swift`, `Equipment.swift`, `ExerciseCategory.swift`
- **Changes**:
  ```swift
  // MuscleGroup.swift
  enum MuscleGroup: String, Codable, CaseIterable, Sendable {
      case chest, back, shoulders, biceps, triceps
      case quadriceps, hamstrings, glutes, calves
      case core, forearms, traps, lats
  }

  // Equipment.swift
  enum Equipment: String, Codable, CaseIterable, Sendable {
      case barbell, dumbbell, machine, cable
      case bodyweight, band, kettlebell, other
  }

  // ExerciseCategory.swift
  enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
      case strength, cardio, hiit, flexibility, bodyweight
  }

  enum ExerciseInputType: String, Codable, Sendable {
      case setsRepsWeight    // 근력: 세트 × 렙 × 무게
      case setsReps          // 바디웨이트: 세트 × 렙
      case durationDistance   // 유산소: 시간 + 거리
      case durationIntensity  // 유연성: 시간 + 강도
      case roundsBased       // HIIT: 라운드 × 시간
  }

  // ExerciseDefinition.swift
  struct ExerciseDefinition: Codable, Identifiable, Sendable {
      let id: String
      let name: String
      let localizedName: String
      let category: ExerciseCategory
      let inputType: ExerciseInputType
      let primaryMuscles: [MuscleGroup]
      let secondaryMuscles: [MuscleGroup]
      let equipment: Equipment
      let metValue: Double  // default 3.5 for strength
  }
  ```
- **Verification**: 빌드 성공. `import Foundation`만 사용. SwiftUI/SwiftData import 없음 확인.

### Step 2: SwiftData 마이그레이션 (V1 → V2)

- **Files**: `Data/Persistence/Migration/AppSchemaVersions.swift`, `Data/Persistence/Models/WorkoutSet.swift`, `Data/Persistence/Models/ExerciseRecord.swift`, `App/DailveApp.swift`
- **Changes**:
  - `AppSchemaV1`: 기존 ExerciseRecord + BodyCompositionRecord 스냅샷
  - `AppSchemaV2`: ExerciseRecord 확장 + WorkoutSet 추가
  - `AppMigrationPlan`: lightweight migration V1 → V2
  - `WorkoutSet` @Model 생성:
    ```swift
    @Model final class WorkoutSet {
        var id: UUID = UUID()
        var exerciseRecord: ExerciseRecord?  // inverse relationship
        var setNumber: Int = 0
        var setTypeRaw: String = "working"  // SetType.rawValue
        var weight: Double?    // kg
        var reps: Int?
        var duration: TimeInterval?   // 유산소/플랭크용
        var distance: Double?         // 유산소용 (meters)
        var isCompleted: Bool = false
        var restDuration: TimeInterval?
    }
    ```
  - `ExerciseRecord` 확장:
    ```swift
    // 신규 필드 (모두 optional 또는 default — CloudKit 호환)
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exerciseRecord)
    var sets: [WorkoutSet] = []
    var exerciseDefinitionID: String?     // 라이브러리 FK
    var primaryMusclesRaw: [String] = []  // MuscleGroup.rawValue 배열
    var secondaryMusclesRaw: [String] = []
    var equipmentRaw: String?
    var estimatedCalories: Double?
    var calorieSourceRaw: String = "manual"  // CalorieSource.rawValue
    ```
  - `DailveApp.swift`: `ModelContainer(for: AppSchemaV2.self, migrationPlan: AppMigrationPlan.self, ...)`
- **Verification**: 빌드 성공. 기존 앱 데이터가 유지되는지 시뮬레이터에서 마이그레이션 확인. WorkoutSet 없는 기존 ExerciseRecord가 정상 로드되는지 확인.

### Step 3: 운동 라이브러리 JSON + 로드 서비스

- **Files**: `Data/Resources/exercises.json`, `Data/ExerciseLibraryService.swift`
- **Changes**:
  - `exercises.json`: 100+ 운동 정의 (id, name, localizedName, category, inputType, primaryMuscles, secondaryMuscles, equipment, metValue)
  - 카테고리별 분포: 가슴 10+, 등 10+, 어깨 8+, 팔 10+, 하체 12+, 코어 8+, 전신 5+, 유산소 10+, 유연성/HIIT 각 5+
  - `ExerciseLibraryService`:
    ```swift
    protocol ExerciseLibraryQuerying: Sendable {
        func allExercises() -> [ExerciseDefinition]
        func exercise(byID id: String) -> ExerciseDefinition?
        func search(query: String) -> [ExerciseDefinition]
        func exercises(forMuscle: MuscleGroup) -> [ExerciseDefinition]
        func exercises(forCategory: ExerciseCategory) -> [ExerciseDefinition]
        func exercises(forEquipment: Equipment) -> [ExerciseDefinition]
    }
    ```
  - 번들 JSON 로드 + 인메모리 캐시 (앱 수명 동안 유지)
  - 검색: `localizedName.localizedCaseInsensitiveContains(query) || name.localizedCaseInsensitiveContains(query)`
- **Verification**: `ExerciseDefinitionTests` — JSON 로드 성공, 100+ 항목, 검색 정확도, 근육 그룹 필터링.

### Step 4: MET 기반 칼로리 추정 서비스

- **Files**: `Domain/UseCases/CalorieEstimationService.swift`
- **Changes**:
  ```swift
  protocol CalorieEstimating: Sendable {
      func estimate(
          metValue: Double,
          bodyWeightKg: Double,
          durationSeconds: TimeInterval,
          restSeconds: TimeInterval  // 총 휴식 시간 (근력 운동)
      ) -> Double?
  }

  struct CalorieEstimationService: CalorieEstimating {
      func estimate(metValue: Double, bodyWeightKg: Double,
                    durationSeconds: TimeInterval, restSeconds: TimeInterval) -> Double? {
          guard metValue > 0, bodyWeightKg > 0, durationSeconds > 0 else { return nil }
          let activeSeconds = max(durationSeconds - restSeconds, 0)
          guard activeSeconds > 0 else { return nil }
          let hours = activeSeconds / 3600.0
          let result = metValue * bodyWeightKg * hours
          guard !result.isNaN, !result.isInfinite, result >= 0 else { return nil }
          return result
      }
  }
  ```
  - 체중 소스: HealthKit `bodyMass` 최신값 → 없으면 BodyCompositionRecord → 없으면 70kg fallback
  - 근력 운동 시 `restSeconds` = 완료된 세트의 `restDuration` 합계
- **Verification**: `CalorieEstimationTests` — 정상 계산, 0 입력, 음수 입력, NaN/Infinite 방어, 휴식 시간 차감.

### Step 5: 휴식 타이머

- **Files**: `Presentation/Exercise/RestTimerViewModel.swift`, `Presentation/Exercise/Components/RestTimerView.swift`
- **Changes**:
  - `RestTimerViewModel`: `@Observable @MainActor` + `Task.sleep(for: .seconds(1))` 루프
    - `start(seconds:)`: cancel-before-spawn + 카운트다운
    - `cancel()`: 타이머 중지
    - `secondsRemaining: Int`, `isRunning: Bool`
    - `Task.isCancelled` guard 후 state 업데이트
  - `RestTimerView`: `.overlay(alignment: .bottom)` 패턴 (Correction Log #28)
    - 남은 시간 표시 (mm:ss)
    - 건너뛰기 버튼
    - `.transition(.move(edge: .bottom).combined(with: .opacity))`
    - `.ultraThinMaterial` 배경
    - Haptic feedback (타이머 종료 시 `.sensoryFeedback(.success)`)
- **Verification**: `RestTimerViewModelTests` — 시작/정지, 카운트다운, 0 도달 시 isRunning=false, cancel 후 상태.

### Step 6: 운동 세션 UI (핵심 입력 화면)

- **Files**: `Presentation/Exercise/WorkoutSessionView.swift`, `WorkoutSessionViewModel.swift`, `Components/SetRowView.swift`, `Components/ExercisePickerView.swift`
- **Changes**:

  **ExercisePickerView** (운동 선택):
  - 검색 바 + 최근 사용 운동 상단 표시
  - 근육 그룹별 섹션 또는 카테고리별 탭
  - 선택 시 `ExerciseDefinition` 반환
  - `@Environment(\.dismiss)` 로 sheet 닫기

  **WorkoutSessionViewModel**:
  - `selectedExercise: ExerciseDefinition?`
  - `sets: [EditableSet]` (UI 전용 모델)
  - `previousSession: [WorkoutSet]?` (이전 기록)
  - `loadPreviousSession(exerciseID:)`: SwiftData 쿼리로 마지막 세션 로드
  - `addSet()`: 이전 값 자동 채움
  - `toggleSetCompletion(index:)`: 완료 토글 → 휴식 타이머 트리거
  - `createValidatedRecord() -> ExerciseRecord?`: 검증 + 레코드 생성
  - `isSaving` guard, `validationError` 패턴 유지
  - 입력 검증: weight 0-500kg, reps 0-1000, duration > 0
  - 칼로리 자동 추정: `CalorieEstimating` 프로토콜 주입

  **SetRowView** (세트 행):
  ```
  ┌─────┬──────┬──────┬────────┬────────┐
  │ SET │  이전  │ KG   │  REPS  │   ✓   │
  ├─────┼──────┼──────┼────────┼────────┤
  │  1  │ 60×10│ [60] │  [10]  │  [✓]  │
  └─────┴──────┴──────┴────────┴────────┘
  ```
  - 이전 값 회색 텍스트 (`.secondary`)
  - 무게/렙: `TextField` with `.keyboardType(.decimalPad)` / `.numberPad`
  - 체크박스: 완료 시 row 배경색 변경 + 휴식 타이머 시작
  - Swipe action: 삭제
  - Long press: 세트 타입 변경 (MVP에서는 visual indicator만, Phase 2에서 타입 분류)

  **WorkoutSessionView** (메인 화면):
  - 상단: 운동 이름 + 근육 그룹 태그 + 장비 아이콘
  - 이전 세션 요약 배너 (있을 경우)
  - 세트 리스트 (`ForEach` + `SetRowView`)
  - 세트 추가 버튼
  - 하단: 운동 완료 버튼 + 추정 칼로리 표시
  - 휴식 타이머 오버레이 (`RestTimerView`)
  - inputType에 따라 필드 자동 전환:
    - `.setsRepsWeight`: KG + REPS 컬럼
    - `.setsReps`: REPS 컬럼만
    - `.durationDistance`: Duration + Distance 필드
    - `.durationIntensity`: Duration + Intensity(1-10) 필드

  **운동 추가 플로우**:
  1. `+` 버튼 탭 → `ExercisePickerView` sheet 표시
  2. 운동 선택 → `WorkoutSessionView` push (NavigationLink)
  3. 세트 기록 → 완료 → `modelContext.insert(record)` → 목록으로 복귀

- **Verification**: `WorkoutSessionViewModelTests` — 세트 추가/삭제, 이전 기록 자동 채움, 유효성 검증, isSaving guard, 칼로리 추정 통합.

### Step 7: Activity 탭 UI 업데이트 + 통합

- **Files**: `ActivityView.swift`, `ExerciseListSection.swift`, `ExerciseView.swift`, `ExerciseViewModel.swift`
- **Changes**:
  - `ActivityView`: `+` 버튼이 ExercisePickerView sheet 열기 → 선택 후 WorkoutSessionView push
  - `AddExerciseSheetWrapper` 제거 (WorkoutSessionView로 대체)
  - `ExerciseListSection`: 세트 정보 표시
    ```
    🏋️ Bench Press  오늘 14:30
       3세트 · 60-65kg · 26렙 · ~180 kcal
    ```
  - `ExerciseView`: AddExerciseSheet 제거, 새 플로우 연결. 기존 레거시 기록(sets 없는)은 기존 방식으로 표시
  - `ExerciseViewModel.ExerciseListItem`: sets 요약 computed property 추가
    ```swift
    var setSummary: String? {
        guard !sets.isEmpty else { return nil }
        let setCount = sets.count
        let weights = sets.compactMap(\.weight)
        let totalReps = sets.compactMap(\.reps).reduce(0, +)
        // "3세트 · 60-65kg · 26렙"
    }
    ```
  - 기존 유산소 입력: duration/distance 방식 유지 (ExerciseInputType으로 분기)
- **Verification**: 시뮬레이터에서 전체 플로우 테스트. 기존 데이터 정상 표시 확인. 새 근력/유산소 기록 생성 확인.

## Edge Cases

| Case | Handling |
|------|----------|
| 이전 기록 없는 첫 세션 | 이전 값 컬럼 "—" 표시, 무게/렙 빈 상태 |
| 기존 "Strength" 레거시 기록 | sets 배열 비어있음 → duration/calories만 표시 (하위 호환) |
| HealthKit 권한 거부 | MET 추정 사용, 체중 없으면 70kg fallback + 설정 유도 |
| 체중 데이터 없음 | 70kg 기본값 사용 + "체중 입력 시 더 정확한 추정" 안내 |
| 운동 중 앱 종료 | 세트 데이터 `@State`에만 있음 → 미저장 (MVP 한계, Phase 2에서 draft 저장) |
| 0kg / 0렙 세트 | 무게 0 허용 (바디웨이트), 렙 0 비허용 (검증 에러) |
| Weight > 500kg | 검증 에러 표시 (Input Validation 규칙) |
| 동일 운동 같은 날 2회 | 마지막 세션의 기록을 이전 기록으로 표시 |
| 커스텀 운동 (라이브러리에 없는) | MVP: exerciseDefinitionID = nil, 사용자가 직접 운동명 입력 |
| 단위 전환 (kg ↔ lb) | MVP: kg 고정. Phase 2에서 설정 화면 추가 |

## Testing Strategy

### Unit Tests

| 파일 | 테스트 항목 |
|------|-----------|
| `ExerciseDefinitionTests` | JSON 로드 성공, 100+ 항목, 검색 정확도, 근육 그룹 필터, 중복 ID 없음 |
| `CalorieEstimationTests` | 정상 계산, 0/음수 입력, NaN/Infinite 방어, 휴식 차감, 체중 fallback |
| `WorkoutSessionViewModelTests` | 세트 CRUD, 이전 기록 채움, 유효성 검증, isSaving, 칼로리 추정 |
| `RestTimerViewModelTests` | 시작/정지/리셋, 카운트다운, 0 도달, cancel-before-spawn |

### Integration Tests

- SwiftData 마이그레이션: V1 → V2 정상 수행 확인 (시뮬레이터)
- ExerciseRecord + WorkoutSet cascade delete 동작 확인

### Manual Verification

- [ ] 근력 운동 기록 전체 플로우 (선택 → 세트 입력 → 완료)
- [ ] 유산소 운동 기록 기존 플로우 정상 동작
- [ ] 이전 세션 기록 표시 정확성
- [ ] 휴식 타이머 동작 + 화면 잠금 중 동작
- [ ] 기존 데이터 마이그레이션 후 정상 표시
- [ ] iPad 레이아웃 확인 (sizeClass 분기)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SwiftData 마이그레이션 실패 | Low | Critical | V1 스냅샷 정확히 정의, 시뮬레이터에서 사전 테스트 |
| CloudKit 동기화 충돌 | Medium | High | 새 필드 모두 optional/default, 기존 디바이스 점진적 업데이트 |
| 100+ 운동 JSON 구축 시간 | High | Medium | 주요 40개 우선 구축, 나머지 점진적 추가 |
| 운동 중 앱 종료 시 데이터 손실 | Medium | Medium | MVP 한계 수용, Phase 2에서 draft auto-save 구현 |
| 휴식 타이머 백그라운드 동작 | Low | Low | foreground만 지원 (MVP), 알림은 Phase 2 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - 기존 코드베이스 패턴(createValidatedRecord, protocol injection, async let, DS 토큰)이 명확하여 새 코드가 자연스럽게 통합됨
  - SwiftData lightweight migration은 optional 필드 추가에 적합
  - MET 기반 칼로리 추정은 2024 Adult Compendium에서 검증된 값 사용
  - 리스크가 가장 큰 항목(운동 JSON 구축)은 점진적 추가로 대응 가능
  - Correction Log의 31개 항목이 모두 반영된 설계
