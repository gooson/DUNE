---
tags: [visionos, ux-polish, spatial-native, hig, typography, window-placement]
date: 2026-03-08
category: plan
status: approved
---

# Plan: visionOS Phase 5B — UX Polish + Spatial Native

## Summary

visionOS HIG를 준수하고 "iOS 복사"가 아닌 공간 네이티브 경험을 제공한다.
Dashboard 단순화, typography 상향, volumetric ornament 분리, window placement, empty state 통일.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | 수정 | "Coming Soon" 제거, 7→4 cards 축소, typography 상향 |
| `DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift` | 수정 | 2D 컨트롤 → ornament 분리, LinearGradient 제거, typography 상향 |
| `DUNEVision/Presentation/Volumetric/HeartRateOrbSceneView.swift` | 수정 | DragGesture 추가 (rotation) |
| `DUNEVision/Presentation/Volumetric/TrainingVolumeBlocksSceneView.swift` | 수정 | DragGesture 추가 (rotation) |
| `DUNEVision/Presentation/Volumetric/BodyHeatmapSceneView.swift` | 수정 | gesture 패턴 통일 |
| `DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift` | 수정 | typography 상향, empty state 통일 |
| `DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift` | 수정 | typography 상향 |
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | 수정 | typography 상향 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift` | 수정 | empty state 통일 |
| `DUNEVision/App/DUNEVisionApp.swift` | 수정 | defaultWindowPlacement 추가 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | 변경/추가 문자열 번역 |

## Implementation Steps

### Step 1: Dashboard 단순화

**목적**: "Coming Soon" 제거 + quick action 7→4 축소

1. conditionSection에서 "Coming Soon" overlay 제거 — 데이터는 이미 snapshot에서 읽히므로 real data 표시
2. healthMetricsSection에서 "Coming Soon" HStack 제거 — 실데이터 표시
3. quickActionsSection 7개 카드 → 4개로 축소:
   - 유지: Condition, Activity, Sleep, Body (dashboard window 열기)
   - 제거: Immersive Space, Spatial Volume, 3D Health Data (toolbar에 이미 있음)
4. 3-column → 2-column grid 전환 (카드 4개이므로 2×2가 적절)
5. 카드 최소 높이 160pt 적용

**검증**: "Coming Soon" 문자열 0건, quick action 4개, 2-column layout

### Step 2: Typography 상향 (.caption → .callout)

**목적**: visionOS 팔 거리 가독성 보장

변경 대상:
- `VisionDashboardView.swift`: `.caption` → `.callout` (metric card labels)
- `VisionVolumetricExperienceView.swift`: `.caption`, `.caption2` → `.callout`
- `VisionMuscleMapExperienceView.swift`: `.caption` → `.callout`
- `VisionExerciseFormGuideView.swift`: `.caption` → `.callout`
- `TrainingVolume3DView.swift`: `.caption2` → `.callout`

**규칙**: `.caption`/`.caption2`는 보조 정보(타임스탬프 등)에만 허용. 메인 레이블은 `.callout` 이상.

**검증**: DUNEVision/ 내 `.caption` 사용이 보조 정보 전용인지 확인

### Step 3: Volumetric Ornament 분리

**목적**: 2D 컨트롤을 volumetric 윈도우에서 분리

VisionVolumetricExperienceView 변경:
1. Scene Picker (segmented) → `.ornament(attachmentAnchor: .scene(.bottom))` 으로 이동
2. Metric strip (BPM, RHR, muscle) → `.ornament(attachmentAnchor: .scene(.trailing))` 으로 이동
3. Muscle strip selector → 같은 trailing ornament에 포함
4. RealityView만 메인 volumetric 컨텐츠로 유지

**검증**: volumetric 윈도우 body에 Picker/Text/Button이 직접 포함되지 않음

### Step 4: LinearGradient 제거

**목적**: volumetric 윈도우의 공간 투명성 확보

VisionVolumetricExperienceView의 `background` computed property 제거.
volumetric 윈도우는 시스템이 관리하는 투명 배경 사용.

**검증**: VisionVolumetricExperienceView에 LinearGradient 0건

### Step 5: Window Placement 추가

**목적**: dashboard 4개 윈도우 + chart3d 윈도우 겹침 방지

DUNEVisionApp.swift에 `.defaultWindowPlacement` 추가:
- condition: 메인 윈도우 왼쪽
- activity: 메인 윈도우 오른쪽
- sleep: 메인 윈도우 왼쪽 아래
- body: 메인 윈도우 오른쪽 아래
- chart3d: 메인 윈도우 위

**검증**: 5개 윈도우 동시 열기 시 겹치지 않음 (시뮬레이터)

### Step 6: Gesture 표준화

**목적**: 모든 3D scene에서 일관된 interaction

공통 패턴 적용:
```swift
// DragGesture for rotation (delta-based)
@State private var yaw: Float = 0
@State private var pitch: Float = 0
@State private var dragStartYaw: Float = 0
@State private var dragStartPitch: Float = 0
```

적용 대상:
- HeartRateOrbSceneView: DragGesture 추가 (현재 없음)
- TrainingVolumeBlocksSceneView: DragGesture 추가 (현재 없음)
- BodyHeatmapSceneView: 이미 적용됨 (유지)

**검증**: 4개 3D scene 모두 drag rotation 지원

### Step 7: Empty State 통일

**목적**: 일관된 empty state 메시지 패턴

규칙:
- "No data" / "No Data" → "No data available" (sentence case)
- 안내 메시지 포함: "Start tracking on iPhone or Apple Watch"
- 아이콘 + 메시지 + 서브텍스트 3단 구조 통일

적용:
- VisionDashboardWindowScene
- VisionMuscleMapExperienceView
- TrainingVolume3DView

**검증**: "No data" (단독) 사용 0건

### Step 8: Localization

새/변경 문자열에 en/ko/ja 번역 추가:
- "No data available" 등 empty state 메시지
- "Coming Soon" 제거 후 대체 텍스트
- ornament 내 레이블

### Step 9: 빌드 검증

- `scripts/build-ios.sh` 실행
- DUNEVision scheme 빌드 검증

## Test Strategy

| 테스트 | 방법 |
|--------|------|
| Dashboard 단순화 | 시뮬레이터 목시 — "Coming Soon" 0건 |
| Typography | Grep 검증 — DUNEVision 내 .caption 보조 전용 |
| Ornament 분리 | 시뮬레이터 — volumetric body에 2D 컨트롤 없음 |
| Window placement | 시뮬레이터 — 5개 윈도우 겹침 없음 |
| Gesture | 시뮬레이터 — 4개 scene drag rotation |
| 빌드 | scripts/build-ios.sh 통과 |

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| `.ornament` API 제한 | visionOS 2+ 필수. iOS 26 target이므로 OK |
| defaultWindowPlacement 시뮬레이터 차이 | 실기기 테스트 권장, 시뮬레이터에서 기본 검증 |
| ornament 내 복잡한 UI | 최소 컨트롤만 배치, 복잡한 설정은 별도 panel |
| typography 변경으로 레이아웃 깨짐 | frame(minWidth:) 적용, 긴 텍스트 truncation |

## Alternatives Considered

1. **탭 3개로 축소 (Life 제거)** — 보류. Life 탭 컨텐츠가 부족하지만 향후 CloudKit 연동 시 활용. 현재는 유지.
2. **별도 SpatialGestureModifier ViewModifier** — 보류. scene마다 rotation 범위/속도가 다르므로 공통 modifier 대신 동일 패턴의 개별 구현이 더 유연.
3. **Skeleton loading / shimmer** — 보류. 현재 데이터 로드가 빠르므로 empty state만 통일. shimmer는 후속 phase에서 검토.
