---
tags: [settings, userdefaults, swiftdata, cloudkit, exercise-defaults, workout-settings]
category: architecture
date: 2026-02-28
severity: important
related_files:
  - DUNE/Data/Persistence/WorkoutSettingsStore.swift
  - DUNE/Data/Persistence/Models/ExerciseDefaultRecord.swift
  - DUNE/Presentation/Settings/SettingsView.swift
  - DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift
  - DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift
  - DUNE/Presentation/Shared/WorkoutDefaults.swift
related_solutions: []
---

# Solution: Settings Hub — Dual Storage Pattern (UserDefaults + SwiftData)

## Problem

앱에 사용자 설정 화면이 없어서 workout defaults(rest time, set count, body weight)가 하드코딩되어 있었고, 운동별 기본 무게를 저장할 방법이 없었음.

### Requirements

- Global workout settings: 빠른 읽기/쓰기, 디바이스 로컬 (UserDefaults)
- Per-exercise defaults: CloudKit 동기화 필요 (SwiftData @Model)
- Today 탭 toolbar gear 아이콘 → Settings push navigation

### Design Decisions

| 항목 | 선택 | 근거 |
|------|------|------|
| Global settings 저장소 | UserDefaults (WorkoutSettingsStore) | 단순 스칼라 값, 동기화 불필요, 빠른 접근 |
| Exercise defaults 저장소 | SwiftData @Model (ExerciseDefaultRecord) | CloudKit 자동 동기화, 관계형 쿼리 |
| Settings 진입 | Push navigation from toolbar | 탭 추가 없이 기존 UX 유지 |
| 공유 상수 접근 | WorkoutDefaults enum (Correction #73) | Cross-VM 의존 방지 |

## Solution

### Architecture

```
SettingsView (Form)
├── Workout Defaults Section (UserDefaults ↔ @State + onChange)
├── Exercise Defaults Section (NavigationLink → ExerciseDefaultsListView)
│   └── ExerciseDefaultEditView (@Query + SwiftData)
├── Theme Section (UI only, no backend)
├── Data & Privacy Section (CloudSync toggle, HealthKit link)
└── About Section (version, build)
```

### Key Patterns

**1. WorkoutSettingsStore: Clamped UserDefaults Singleton**

```swift
final class WorkoutSettingsStore: @unchecked Sendable {
    static let shared = WorkoutSettingsStore()
    private let defaults: UserDefaults
    private let prefix: String // Bundle.main.bundleIdentifier (Correction #76)

    var restSeconds: TimeInterval {
        get { defaults.double(forKey: key).clamped(to: range) }
        set { defaults.set(newValue.clamped(to: range), forKey: key) }
    }
}
```

- Clamped getter/setter로 범위 보장 (Correction #3)
- DI 가능한 init(defaults:)로 테스트 격리 가능
- `@unchecked Sendable`로 concurrent 접근 허용

**2. WorkoutDefaults: 중립 enum으로 Cross-VM 참조**

```swift
enum WorkoutDefaults {
    static var setCount: Int { WorkoutSettingsStore.shared.setCount }
    static var restSeconds: TimeInterval { WorkoutSettingsStore.shared.restSeconds }
}
```

ViewModel들이 `WorkoutSettingsStore`를 직접 참조하지 않고 `WorkoutDefaults`를 통해 접근 (Correction #73).

**3. ExerciseDefaultsListView: @State Dictionary Cache**

```swift
@State private var defaultsByExerciseID: [String: ExerciseDefaultRecord] = [:]

// ForEach에서 O(1) 접근
exerciseRow(exercise: exercise, record: defaultsByExerciseID[exercise.id])

// @Query 변경 시 재빌드
.onChange(of: savedDefaults.count) { rebuildDefaultsIndex() }
```

Correction #68: ForEach 내 O(N) lookup → Dictionary cache로 O(1) 접근.

**4. ExerciseDefaultEditView: CloudKit Delete Safety**

```swift
@State private var isSaving: Bool = false      // Correction #6: 중복 저장 방지
@State private var showClearConfirmation = false // Correction #50: 삭제 확인

Button("Clear Defaults", role: .destructive) {
    showClearConfirmation = true // dialog 먼저
}
.confirmationDialog("Clear exercise defaults?", isPresented: $showClearConfirmation) {
    Button("Clear Defaults", role: .destructive) { clearDefaults() }
}
```

## Prevention

### Checklist

- [ ] 새 settings 항목 추가 시 `WorkoutSettingsStore`에 range + clamping 포함
- [ ] SwiftData @Model 추가 시 `DUNEApp.swift`의 ModelContainer에 등록
- [ ] ForEach에서 @Query 결과 조회 시 Dictionary cache 사용 (Correction #68)
- [ ] CloudKit 삭제 전 confirmationDialog 필수 (Correction #50)
- [ ] Settings에서 UserDefaults 값 편집 시 `@State` + `onChange` 패턴 사용

## Lessons Learned

1. **Dual storage가 적절한 경우**: Global scalar → UserDefaults, Entity with sync → SwiftData. 둘을 같은 저장소에 넣으면 불필요한 복잡도 증가
2. **@Query + ForEach = O(N²) 함정**: @Query 결과를 ForEach 내에서 `.first(where:)`로 조회하면 매 row마다 O(N). 반드시 Dictionary로 전처리
3. **Weight 0 ≠ nil**: 무게 0.0은 "무게 없음"이 아니라 "체중 운동"으로 오해될 수 있음. `parsed > 0 ? value : nil` 패턴으로 구분
