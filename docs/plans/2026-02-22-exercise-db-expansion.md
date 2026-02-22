---
topic: exercise-db-expansion
date: 2026-02-22
status: draft
confidence: high
related_solutions: [input-validation-swiftdata, cloudkit-optional-relationship, viewmodel-cached-filtering]
related_brainstorms: [2026-02-22-exercise-db-expansion, 2026-02-17-exercise-visual-guide]
---

# Implementation Plan: 운동 및 장비 데이터베이스 대규모 확장

## Context

현재 127개 운동, 8개 장비 타입으로는 사용자가 헬스장에서 마주하는 실제 운동/기구의 다양성을 커버하지 못함. "machine"이라는 단일 카테고리에 수십 종류의 기구가 뭉쳐 있고, 동의어 검색이 불가하며, 기구 참고 이미지가 없음.

**핵심 변경:**
1. Equipment enum 세분화 (8 → 25개)
2. ExerciseDefinition에 aliases/difficulty/tags 필드 추가
3. exercises.json 확장 (127 → 500+ exercises)
4. 검색에 alias 매칭 추가
5. 기존 운동의 equipment 값 migration

## Requirements

### Functional

- F1: Equipment enum을 25개로 확장하여 machine 카테고리를 세분화
- F2: ExerciseDefinition에 `aliases`, `difficulty`, `tags` optional 필드 추가
- F3: exercises.json을 500개 이상으로 확장 (strength, cardio, flexibility, HIIT, olympic, sports)
- F4: 각 운동에 2-3개 한/영 alias 추가
- F5: ExerciseLibraryService.search()에 alias 매칭 로직 추가
- F6: 기존 "machine" 운동을 세분화된 equipment으로 migration
- F7: Equipment+View.swift에 새 장비의 displayName, localizedName, icon, description 추가
- F8: EquipmentIllustrationView에 새 장비의 Canvas 드로잉 추가

### Non-functional

- NF1: JSON 파싱 성능 유지 (500개 × ~250B = ~125KB, 번들 로딩에 무시할 수준)
- NF2: 기존 ExerciseRecord의 exerciseDefinitionID 호환성 유지 (ID 변경 불가)
- NF3: 기존 "machine" rawValue로 저장된 CustomExercise/ExerciseRecord 호환
- NF4: 빌드 경고 0 유지 (exhaustive switch 전부 업데이트)
- NF5: 테스트 통과 유지 + 새 필드 테스트 추가

## Approach

**점진적 확장 (Incremental Expansion)**: 스키마 변경 → 데이터 확장 → 검색 개선 순서로 진행. 각 단계가 독립적으로 빌드 가능하도록 구성.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Equipment을 struct로 변환 | 유연한 확장, 런타임 추가 가능 | CaseIterable 불가, switch 불가, 기존 코드 대규모 변경 | **기각** — enum 유지가 타입 안전성 높고 변경 범위 최소 |
| Machine을 하위 enum으로 (Equipment.machine(.legPress)) | 계층적 구조, 기존 "machine" 호환 | nested enum은 Codable 복잡, JSON 구조 변경 | **기각** — flat enum이 단순하고 JSON 호환 |
| 별도 equipment-aliases.json 파일 | 관심사 분리 | 두 파일 동기화 비용, 로딩 복잡 | **기각** — 단일 JSON 관리 용이 |
| **Equipment enum flat 확장 (선택)** | 타입 안전, Codable 자동, switch exhaustive | case 많아짐 (25개) | **채택** — 컴파일러가 누락 방지 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/Equipment.swift` | **Modify** | 8 → 25 cases 추가 |
| `Domain/Models/ExerciseDefinition.swift` | **Modify** | aliases, difficulty, tags 필드 추가 |
| `Presentation/Shared/Extensions/Equipment+View.swift` | **Modify** | 4개 switch에 17개 case 추가 |
| `Presentation/Shared/Components/EquipmentIllustrationView.swift` | **Modify** | switch + draw 메서드 17개 추가 |
| `Data/ExerciseLibraryService.swift` | **Modify** | search()에 alias 매칭 추가 |
| `Data/Resources/exercises.json` | **Modify** | 127 → 500+ exercises, equipment migration |
| `Data/ExerciseDescriptions.swift` | **Modify** | 새 운동의 descriptions/form cues 추가 |
| `Data/Persistence/Models/CustomExercise.swift` | **Review** | fallback 로직 확인 (line 61) |
| `Domain/Protocols/ExerciseLibraryQuerying.swift` | **No change** | 기존 인터페이스 호환 |
| `DailveTests/ExerciseDefinitionTests.swift` | **Modify** | 새 필드 테스트 + alias 검색 테스트 추가 |

## Implementation Steps

### Step 1: Equipment enum 확장

- **Files**: `Domain/Models/Equipment.swift`
- **Changes**:
  - 기존 8개 case 유지
  - 17개 case 추가:
    ```swift
    // Free Weights
    case ezBar
    case trapBar
    // Machines (machine 해체)
    case smithMachine
    case legPressMachine
    case hackSquatMachine
    case chestPressMachine
    case shoulderPressMachine
    case latPulldownMachine
    case legExtensionMachine
    case legCurlMachine
    case pecDeckMachine
    case cableMachine
    // Bodyweight Accessories
    case pullUpBar
    case dipStation
    // Accessories
    case trx
    case medicineBall
    case stabilityBall
    ```
  - 기존 `machine` case는 **유지** (하위 호환: 기존 CustomExercise/ExerciseRecord에서 rawValue "machine"으로 저장된 데이터)
  - 기존 `cable` case도 **유지** (기존 데이터 호환)
- **Verification**: 빌드 시 모든 exhaustive switch에서 컴파일 에러 발생 → Step 2에서 해결

### Step 2: Equipment+View.swift 업데이트

- **Files**: `Presentation/Shared/Extensions/Equipment+View.swift`
- **Changes**: 4개 switch 문에 17개 새 case 추가
  - `displayName`: English name (e.g., "Smith Machine", "EZ Bar")
  - `localizedDisplayName`: Korean name (e.g., "스미스 머신", "이지바")
  - `equipmentDescription`: Korean 1-2줄 설명
  - `iconName`: SF Symbol 매핑
- **SF Symbol 매핑 전략**:
  - smithMachine → `"figure.strengthtraining.traditional"`
  - legPressMachine → `"figure.strengthtraining.functional"`
  - Free weights (ezBar, trapBar) → `"dumbbell.fill"`
  - Bodyweight accessories (pullUpBar, dipStation) → `"figure.stand"`
  - Accessories (trx, medicineBall, stabilityBall) → `"circle.dashed"`
- **Verification**: 빌드 성공, 경고 0

### Step 3: EquipmentIllustrationView 업데이트

- **Files**: `Presentation/Shared/Components/EquipmentIllustrationView.swift`
- **Changes**:
  - switch 문에 17개 case 추가
  - 각 case별 `draw{Equipment}()` 메서드 구현
  - 복잡한 기구는 기존 `drawMachine()` 패턴 재활용 (직사각형 + 심볼)
  - 단순 기구 (ezBar, trapBar 등)는 `drawBarbell()` 변형
- **Verification**: Preview에서 Equipment.allCases 전체 렌더링 확인

### Step 4: ExerciseDefinition 스키마 확장

- **Files**: `Domain/Models/ExerciseDefinition.swift`
- **Changes**:
  ```swift
  let aliases: [String]?       // 검색용 별명 (한/영 혼합)
  let difficulty: String?      // "beginner" / "intermediate" / "advanced"
  let tags: [String]?          // 자유 태그 (compound, push, pull, isolation 등)
  ```
  - `init()`에 3개 파라미터 추가 (모두 `= nil` 기본값 → 기존 호출 코드 호환)
  - Codable 자동 지원 (optional 필드는 JSON에 없으면 nil)
- **Verification**: 기존 exercises.json 파싱 성공 (새 필드 없는 기존 데이터도 호환)

### Step 5: ExerciseLibraryService 검색 개선

- **Files**: `Data/ExerciseLibraryService.swift`
- **Changes**:
  - `search(query:)` 메서드에 alias 매칭 추가:
    ```swift
    func search(query: String) -> [ExerciseDefinition] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter { exercise in
            exercise.localizedName.localizedCaseInsensitiveContains(query)
                || exercise.name.localizedCaseInsensitiveContains(query)
                || (exercise.aliases ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    ```
  - alias 전용 Dictionary 캐시 추가 (optional, 성능 필요 시):
    ```swift
    private let aliasIndex: [String: String]  // lowercased alias → exercise ID
    ```
- **Verification**: "벤치" 검색 → "Barbell Bench Press" + alias "플랫 벤치" 매칭 확인

### Step 6: exercises.json 확장 — 기존 운동 migration

- **Files**: `Data/Resources/exercises.json`
- **Changes**:
  - 기존 127개 운동의 `equipment` 값을 세분화:
    - `"chest-press-machine"` → equipment: `"chestPressMachine"` (기존: `"machine"`)
    - `"shoulder-press-machine"` → equipment: `"shoulderPressMachine"` (기존: `"machine"`)
    - `"lat-pulldown"` → equipment: `"latPulldownMachine"` (기존: `"cable"`)
    - `"leg-press"` → equipment: `"legPressMachine"` (기존: `"machine"`)
    - `"leg-extension"` → equipment: `"legExtensionMachine"` (기존: `"machine"`)
    - `"leg-curl"` → equipment: `"legCurlMachine"` (기존: `"machine"`)
    - `"hack-squat"` → equipment: `"hackSquatMachine"` (기존: `"machine"`)
    - `"pec-deck"` → equipment: `"pecDeckMachine"` (기존: `"machine"`)
    - `"calf-raise"` → equipment: `"machine"` (유지 — 다양한 카프레이즈 머신)
    - `"hip-abduction-machine"` → equipment: `"machine"` (유지)
    - `"hip-adduction-machine"` → equipment: `"machine"` (유지)
    - 카디오 머신은 equipment 유지: `"cycling"`, `"elliptical"`, `"stair-climber"` → `"machine"` (유지)
  - 기존 운동에 aliases 추가:
    ```json
    {
      "id": "barbell-bench-press",
      "aliases": ["Flat Bench Press", "플랫 벤치", "Bench Press", "벤치 프레스"],
      ...
    }
    ```
- **주의**: 기존 운동의 `id` 는 절대 변경 불가 (ExerciseRecord 참조)
- **Verification**: JSON 파싱 성공, 기존 테스트 통과

### Step 7: exercises.json 확장 — 새 운동 대규모 추가

- **Files**: `Data/Resources/exercises.json`
- **Changes**: 카테고리별 새 운동 추가 (목표: 500+ total)
  - **Strength 추가 (~200개)**: 각 근육 그룹별 변형 운동
    - Chest: Incline DB Fly, Cable Fly, Floor Press, Landmine Press 등
    - Back: Meadows Row, Pendlay Row, Cable Pullover, Straight-arm Pulldown 등
    - Shoulders: Lu Raise, Bradford Press, Behind-neck Press, Machine Lateral Raise 등
    - Arms: Spider Curl, Bayesian Curl, JM Press, Diamond Push-up 등
    - Legs: Sissy Squat, Pendulum Squat, Belt Squat, Nordic Curl 등
    - Core: Pallof Press, Woodchop, Dragon Flag, V-up 등
  - **Bodyweight 추가 (~40개)**: Muscle-up, Handstand Push-up, L-sit, Pistol Squat, Archer Push-up 등
  - **Cardio 추가 (~30개)**: Assault Bike, Ski Erg, Sprint Intervals, Swimming Drills 등
  - **HIIT 추가 (~25개)**: Wall Balls, KB Snatch, Man Maker, Devil Press 등
  - **Flexibility 추가 (~30개)**: Cat-Cow, Pigeon Stretch, Hip Flexor Stretch, Thoracic Rotation 등
  - **Olympic 추가 (~15개)**: Snatch, Clean & Jerk, Hang Clean, Push Press, Jerk 등
  - **Sports 추가 (~20개)**: Boxing, Shadow Boxing, Swimming Drills, Jump Training 등
- **데이터 품질 기준**:
  - 모든 운동은 id (kebab-case), name (English), localizedName (Korean) 필수
  - primaryMuscles 최소 1개
  - MET 값: 0.9-30.0 범위 (Correction #42)
  - aliases 최소 1개 (한국어 변형 또는 약어)
- **Verification**: JSON validity, 파싱 성공, 전체 테스트 통과

### Step 8: ExerciseDescriptions 확장

- **Files**: `Data/ExerciseDescriptions.swift`
- **Changes**: 주요 새 운동의 description + form cues 추가
  - 우선순위: Olympic lifts, 복합 운동, 머신 운동 (초보자 안내 중요)
  - 모든 500개에 descriptions 필요하지 않음 — 주요 100개에 우선 추가
- **Verification**: ExerciseDetailSheet에서 description 표시 확인

### Step 9: CustomExercise fallback 검토

- **Files**: `Data/Persistence/Models/CustomExercise.swift`
- **Changes**:
  - Line 61: `Equipment(rawValue: equipmentRaw) ?? .bodyweight`
  - 기존 `.bodyweight` fallback 유지 (합리적 기본값)
  - 새 equipment case의 rawValue가 camelCase임을 확인 (JSON 호환)
- **Verification**: CustomExercise 생성/로딩 테스트

### Step 10: 테스트 업데이트

- **Files**: `DailveTests/ExerciseDefinitionTests.swift`
- **Changes**:
  ```swift
  @Test("Library loads 500+ exercises")
  func loadsAll() {
      let all = library.allExercises()
      #expect(all.count >= 500)
  }

  @Test("Search finds exercises by alias")
  func searchByAlias() {
      let results = library.search(query: "플랫 벤치")
      #expect(!results.isEmpty)
      #expect(results.contains { $0.id == "barbell-bench-press" })
  }

  @Test("Exercises with aliases have non-empty alias arrays")
  func aliasesAreValid() {
      let withAliases = library.allExercises().filter { $0.aliases != nil }
      for exercise in withAliases {
          #expect(!(exercise.aliases ?? []).isEmpty, "\(exercise.id) has empty aliases array")
      }
  }

  @Test("New equipment types have exercises")
  func newEquipmentHasExercises() {
      let newTypes: [Equipment] = [.smithMachine, .ezBar, .trapBar, .trx]
      for equip in newTypes {
          let exercises = library.exercises(forEquipment: equip)
          #expect(!exercises.isEmpty, "No exercises for \(equip)")
      }
  }

  @Test("MET values are within physiological range")
  func metValuesInRange() {
      for exercise in library.allExercises() {
          #expect(exercise.metValue >= 0.9 && exercise.metValue <= 30.0,
                  "\(exercise.id) MET \(exercise.metValue) out of range")
      }
  }
  ```
- **Verification**: 전체 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 기존 "machine" rawValue로 저장된 ExerciseRecord | `Equipment(rawValue:)` 로 정상 디코딩 — `machine` case 유지 |
| 기존 "cable" rawValue로 저장된 ExerciseRecord | `cable` case 유지, `cableMachine`과 별도 |
| CustomExercise의 unknown rawValue | `.bodyweight` fallback (기존 로직 유지) |
| aliases가 nil인 기존 운동 | `(exercise.aliases ?? [])` 로 빈 배열 처리 |
| 500개 운동 로딩 성능 | ~125KB JSON, 0.01초 미만 파싱 예상. 문제 시 lazy loading 고려 |
| alias false positive ("row" → Barbell Row + Rowing Machine) | name/localizedName 매칭을 alias보다 우선 정렬 |
| duplicate exercise IDs | 테스트에서 uniqueIDs 검증 (기존 테스트 유지) |
| camelCase rawValue JSON 호환 | `smithMachine` → JSON `"smithMachine"` 자동 |

## Testing Strategy

- **Unit tests**: ExerciseDefinitionTests.swift — 500+ 로딩, alias 검색, 새 equipment 필터, MET 범위
- **Integration tests**: 해당 없음 (SwiftData 영역 아님)
- **Manual verification**:
  - ExercisePickerView에서 25개 equipment 필터 칩 표시 확인
  - CreateCustomExerciseView에서 새 equipment Picker 표시 확인
  - EquipmentIllustrationView Preview에서 25개 일러스트 렌더링 확인
  - ExerciseDetailSheet에서 새 운동의 info 표시 확인
  - "스미스 머신 스쿼트" 검색 → 정상 매칭 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Equipment 25개 → Picker UI 스크롤 필요 | High | Low | horizontal scroll chips 유지, 빈번 사용 순서로 정렬 |
| 500개 JSON 파싱 지연 | Low | Medium | ~125KB, 측정 후 필요 시 최적화 |
| 한국어 localizedName 품질 | Medium | Medium | 한국 피트니스 커뮤니티 표준 용어 사용, 리뷰 단계에서 검증 |
| 기존 "machine" 운동의 equipment 변경 → ExerciseRecord 불일치 | Low | High | ExerciseRecord는 exerciseDefinitionID로 참조, equipment는 record 내 rawEquipment로 별도 저장 → 영향 없음 |
| EquipmentIllustrationView 17개 draw 메서드 추가 | High | Low | 기존 패턴 재활용 (drawMachine 변형), 단계적 구현 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - Equipment enum 확장은 컴파일러가 누락 방지 (exhaustive switch)
  - ExerciseDefinition 필드 추가는 optional이므로 하위 호환
  - exercises.json 확장은 데이터 작업 (코드 변경 최소)
  - 기존 패턴 (singleton, Codable, search) 을 그대로 활용
  - 가장 큰 작업량은 JSON 데이터 수집이지만 기술적 리스크는 낮음
