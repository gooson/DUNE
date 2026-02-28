---
tags: [settings, preferences, theme, workout-defaults, ux]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: Settings Hub (Today 탭 진입점)

## Problem Statement

현재 앱에 사용자 설정 화면이 없음. 운동 기본값(쉬는 시간, 세트 수, 체중)이 `WorkoutDefaults`/`WorkoutSessionViewModel`에 하드코딩되어 있고, 디자인 테마는 단일(desert warm)만 존재. 사용자가 자신의 운동 습관에 맞게 앱을 커스터마이즈할 수 없는 상태.

## Target Users

- 정기적으로 근력 운동하는 사용자 (주 3-5회)
- 운동마다 다른 무게/쉬는 시간을 사용하는 중급+ 사용자
- 앱 외관을 자기 취향에 맞추고 싶은 사용자

## Success Criteria

1. Today 탭 상단 우측 gear 아이콘으로 설정 진입 가능
2. 기본 쉬는 시간/세트 수를 사용자가 변경 가능
3. 운동별 마지막 사용 무게가 다음 세션 기본값으로 자동 적용
4. 2-3개 프리셋 테마 중 선택 가능
5. CloudSync 토글, HealthKit 권한 관리, 앱 정보 통합

## Proposed Approach

### 1. 진입점: Today Toolbar Gear Icon

```
DashboardView
  .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
          NavigationLink(value: AppRoute.settings) {
              Image(systemName: "gearshape")
          }
      }
  }
```

- `ContentView`의 `NavigationStack`이 push 처리 (Correction #48: root stack 소유권)
- `AppRoute.settings` enum case 추가 (Correction #61: type-safe routing)

### 2. 설정 화면 구조 (Sections)

```
SettingsView
├── Section: Workout Defaults
│   ├── Default Rest Time (Stepper: 30-300초, 15초 단위)
│   ├── Default Set Count (Stepper: 1-10)
│   └── Default Body Weight (kg input)
│
├── Section: Exercise Defaults
│   └── NavigationLink → ExerciseDefaultsListView
│       ├── 운동 목록 (최근 사용 순)
│       └── 각 운동 tap → 기본 무게/세트 수 편집
│
├── Section: Appearance
│   ├── Theme Picker (Desert Warm / Ocean Cool / Forest Green)
│   └── (Future) Custom Accent Color
│
├── Section: Data & Privacy
│   ├── CloudSync Toggle (기존 AppStorage 연동)
│   ├── HealthKit Permissions → System Settings
│   └── Export Data (Future)
│
├── Section: About
│   ├── App Version
│   ├── Build Number
│   └── Licenses / Acknowledgments
│
└── Section: Support
    ├── Send Feedback (mailto:)
    └── Rate App (StoreKit)
```

### 3. 운동별 기본 무게 — 자동 기억 방식

**두 가지 병행:**

1. **자동 기억 (Last Used Weight)**: 운동 세션 완료 시 마지막 세트의 무게를 `ExerciseDefaultsStore`에 자동 저장. 다음 세션 시작 시 해당 무게를 기본값으로 pre-fill.

2. **수동 오버라이드**: Settings → Exercise Defaults에서 특정 운동의 기본 무게를 직접 설정. 수동 설정값이 자동 기억값보다 우선.

**저장 구조:**
```swift
// Data/Persistence/ExerciseDefaultsStore.swift
struct ExerciseDefault: Codable {
    let exerciseID: String        // ExerciseDefinition.id
    var defaultWeight: Double?    // kg
    var defaultReps: Int?         // optional
    var isManualOverride: Bool    // 수동 설정 여부
    var lastUsedDate: Date        // 마지막 사용일
}

// UserDefaults key: "{bundleID}.exerciseDefaults.{exerciseID}"
```

**우선순위:**
1. 수동 설정값 (`isManualOverride == true`)
2. 자동 기억값 (마지막 세션의 무게)
3. 글로벌 기본값 (`WorkoutDefaults.defaultWeight` → 설정에서 변경 가능)

### 4. 디자인 테마 — 프리셋 3종

| 테마 | Primary | Background | Accent | Wave |
|------|---------|------------|--------|------|
| Desert Warm (현재) | Amber/Sand | Dark brown gradient | Orange-gold | Warm sand |
| Ocean Cool | Steel blue | Deep navy gradient | Cyan-teal | Cool wave |
| Forest Green | Sage | Dark forest gradient | Emerald | Moss green |

**구현 방식:**
- `DS.Theme` enum 추가: `.desertWarm`, `.oceanCool`, `.forestGreen`
- 각 테마가 `DS.Color`, `DS.Gradient`, wave 색상을 결정
- `@AppStorage("selectedTheme")` 로 저장
- `EnvironmentKey`로 전파 → 기존 `DS.Color.*` 접근을 theme-aware로 전환

**주의:** 기존 DS 구조(static let) 대폭 수정 필요. Environment 기반으로 전환하는 것이 안전.

### 5. Data & Privacy

- **CloudSync Toggle**: 기존 `@AppStorage("isCloudSyncEnabled")` 재사용
- **HealthKit**: `UIApplication.openSettings()` → Health 권한 화면
- **Export**: Future scope (JSON/CSV 내보내기)

## Constraints

### 기술적 제약
- DS(DesignSystem)가 `static let` 기반 → 테마 전환 시 Environment 기반으로 리팩토링 필요
- `WorkoutDefaults`가 `enum` static 프로퍼티 → `@Observable` 클래스 또는 Store로 전환 필요
- CloudKit은 UserDefaults를 동기화하지 않음 → 설정은 기기별 로컬 저장

### 시간 제약
- 테마 시스템 리팩토링은 DS를 사용하는 100+ 파일에 영향 → 가장 시간 소요 큰 항목

## Edge Cases

1. **운동별 기본 무게 — 데이터 없음**: 한 번도 수행하지 않은 운동은 글로벌 기본값 사용
2. **테마 전환 중 애니메이션**: `.animation(.easeInOut)` + `.id(theme)` 패턴으로 smooth transition
3. **설정 마이그레이션**: 기존 하드코딩 값 → UserDefaults 마이그레이션 시 기존 사용자는 현재 기본값 유지
4. **iCloud 비활성화 후 재활성화**: 설정은 로컬이므로 영향 없음
5. **운동 삭제/이름 변경**: `exerciseID` 기반이므로 이름 변경에 안전. 삭제된 운동의 기본값은 garbage collection (Correction #75)

## Scope

### MVP (Must-have)
- [ ] Today toolbar gear icon → Settings push navigation
- [ ] Workout Defaults 섹션 (쉬는 시간, 세트 수, 기본 체중)
- [ ] Exercise Defaults 자동 기억 (마지막 무게 저장/복원)
- [ ] Exercise Defaults 수동 편집 (Settings → 운동 목록 → 편집)
- [ ] 테마 프리셋 3종 (Desert Warm / Ocean Cool / Forest Green)
- [ ] Data & Privacy (CloudSync 토글, HealthKit 링크)
- [ ] About (버전, 빌드)

### Nice-to-have (Future)
- [ ] 커스텀 accent color picker
- [ ] 데이터 내보내기 (JSON/CSV)
- [ ] 운동별 기본 쉬는 시간 (글로벌이 아닌 운동별)
- [ ] 알림 설정 (운동 리마인더)
- [ ] 단위 전환 (kg ↔ lbs)
- [ ] Haptic feedback 강도 조절
- [ ] Watch 설정 동기화

## Decisions (2026-02-28)

1. **테마**: 새 테마 추가하지 않음. 설정 화면에 테마 선택 UI만 구성 (현재 Desert Warm 1개 + "Coming Soon" 표시). 실제 테마 추가는 별도 태스크
2. **운동별 무게 저장**: SwiftData `@Model` — CloudKit 동기화 필요
3. **Settings 진입**: NavigationLink push 확정

## Next Steps

- [ ] `/plan settings-hub` 으로 구현 계획 생성
