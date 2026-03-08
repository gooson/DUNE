---
tags: [e2e, ui-test, muscle-map, 3d-view, xcuitest]
date: 2026-03-09
category: plan
status: draft
---

# E2E UI Tests: MuscleMapDetailView + MuscleMap3DView

## Problem Statement

TODO 043/044 — MuscleMapDetailView와 MuscleMap3DView의 E2E UI 테스트 surface를 정의하고 구현한다.
기존 `ActivityExerciseRegressionTests`에는 MuscleMap 섹션 탭 → DetailView 진입 확인만 있고,
DetailView 내부 interaction과 3DView 전환/interaction 테스트가 없다.

## Scope

- MuscleMapDetailView: recovery map 표시, volume breakdown, recovery overview, muscle selection
- MuscleMap3DView: 3D 진입, mode picker, summary card, muscle strip selection
- Simulator-safe assertions (ARView는 시뮬레이터에서 렌더링 제한 있음)

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | Modify | AXID 추가 (screen, mode picker, summary, muscle strip, reset) |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift` | Modify | 필요 시 추가 AXID (volume section, recovery section) |
| `DUNE/Presentation/Activity/MuscleMap/Components/VolumeBreakdownSection.swift` | Modify | AXID 추가 |
| `DUNE/Presentation/Activity/MuscleMap/Components/RecoveryOverviewSection.swift` | Modify | AXID 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | Modify | AXID enum에 새 상수 추가 |
| `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` | Create | 새 테스트 파일 |
| `todos/043-ready-p2-e2e-dune-muscle-map-detail-view.md` | Modify | status → done |
| `todos/044-ready-p2-e2e-dune-muscle-map-3d-view.md` | Modify | status → done |

## Implementation Steps

### Step 1: AXID 추가 — MuscleMap3DView

MuscleMap3DView.swift에 accessibility identifier 추가:

- Screen-level: `"activity-musclemap-3d-screen"` (ScrollView에)
- Mode Picker: `"musclemap-3d-mode-picker"`
- Summary Card: `"musclemap-3d-summary-card"`
- Muscle Selection Strip: `"musclemap-3d-muscle-strip"`
- Reset Button: toolbar reset → `"musclemap-3d-reset-button"`

**Verification**: 빌드 성공

### Step 2: AXID 추가 — MuscleMapDetailView 하위 컴포넌트

추가 AXID:
- VolumeBreakdownSection: `"musclemap-detail-volume-section"`
- RecoveryOverviewSection: `"musclemap-detail-recovery-section"`
- 3D 전환 버튼: `"musclemap-detail-3d-button"` (이미 존재하는지 확인 필요)

**Verification**: 빌드 성공

### Step 3: AXID Registry 업데이트

UITestHelpers.swift의 AXID enum에 새 상수 추가:
- `activityMuscleMap3DScreen`
- `muscleMap3DModePicker`
- `muscleMap3DSummaryCard`
- `muscleMap3DMuscleStrip`
- `muscleMap3DResetButton`
- `muscleMapDetailVolumeSection`
- `muscleMapDetailRecoverySection`
- `muscleMapDetail3DButton`

**Verification**: 빌드 성공

### Step 4: 테스트 파일 생성 — ActivityMuscleMapRegressionTests

`DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` 생성.
`ActivityExerciseSeededUITestBaseCase` 상속 (seeded data 필요).

테스트 케이스:

**MuscleMapDetailView Tests:**
1. `testMuscleMapDetailViewLoads` — 섹션 탭 → detail screen AXID 존재 확인
2. `testMuscleMapDetailViewShowsVolumeSectionWithSeededData` — volume section AXID 존재
3. `testMuscleMapDetailViewShowsRecoverySectionWithSeededData` — recovery section AXID 존재
4. `testMuscleMapDetailViewNavigatesTo3D` — 3D 버튼 탭 → 3D screen AXID 존재

**MuscleMap3DView Tests:**
5. `testMuscleMap3DViewLoads` — 3D screen AXID + summary card + mode picker 존재
6. `testMuscleMap3DViewModePickerSwitches` — recovery/volume 모드 전환, summary card 텍스트 변경
7. `testMuscleMap3DViewMuscleStripExists` — muscle strip AXID 존재 + capsule 버튼들 존재
8. `testMuscleMap3DViewResetButton` — reset 버튼 존재 및 탭 가능

**Simulator-safe 3D 검증 전략:**
- ARView 렌더 결과(entity 탭, 회전)는 시뮬레이터에서 신뢰할 수 없음
- 대신 SwiftUI overlay (summary card, mode picker, muscle strip) 존재/상태만 검증
- 3D viewer 영역은 `.exists` 확인만 (content 검증 불가)

**Verification**: 테스트 빌드 성공

### Step 5: 테스트 실행 및 검증

```bash
xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' \
  -only-testing DUNEUITests/ActivityMuscleMapRegressionTests
```

### Step 6: TODO 상태 업데이트

- `043` → `done`
- `044` → `done`

## Test Strategy

- **Lane**: PR Gate (빠른 실행, seeded data, simulator-safe)
- **Base Class**: `ActivityExerciseSeededUITestBaseCase` (`.activityExerciseSeeded` scenario)
- **Entry Route**: Activity tab → scroll to muscle map section → tap → MuscleMapDetailView → 3D button → MuscleMap3DView
- **Data Requirement**: seeded exercise records with muscle group data (ActivityExerciseSeeded scenario provides this)

## Risks & Edge Cases

1. **ARView on Simulator**: RealityKit ARView renders limited content on simulator. All 3D-specific assertions must be view-existence only, not content-based.
2. **Scroll Position**: Muscle map section may require scrolling. Use `scrollToElementIfNeeded` pattern.
3. **Seeded Data Coverage**: ActivityExerciseSeeded scenario must include muscle fatigue data for meaningful volume/recovery sections. If empty, tests degrade to empty-state verification.
4. **Test Plan Assignment**: New test file should be included in both PR and Full test plans. Verify xctestplan auto-discovery.

## Alternatives Considered

1. **SnapshotTesting for 3D**: Rejected — simulator ARView renders differently per OS version, brittle snapshots
2. **Separate test files per view**: Rejected — both views share entry route and seeded data, consolidation reduces setup duplication
