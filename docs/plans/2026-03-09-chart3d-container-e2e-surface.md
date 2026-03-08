---
tags: [visionos, e2e, accessibility, chart3d, ui-test]
date: 2026-03-09
category: plan
status: draft
---

# Plan: E2E Surface — DUNEVision Chart3DContainerView

## Summary

TODO 088의 4개 체크리스트를 완료한다. Chart3DContainerView와 자식 뷰(ConditionScatter3DView, TrainingVolume3DView)에 accessibility identifier를 고정하고, 기존 `VisionSurfaceAccessibility` helper에 등록, 테스트로 안정성을 확보한다.

## Affected Files

| File | Action | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | 수정 | Chart3D AXID 추가 |
| `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift` | 수정 | AXID 연결 |
| `DUNEVision/Presentation/Chart3D/ConditionScatter3DView.swift` | 수정 | 차트 뷰 AXID 연결 |
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | 수정 | 차트 뷰 AXID 연결 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | 수정 | 새 AXID 안정성 테스트 |
| `todos/088-ready-p3-e2e-dunevision-chart3d-container-view.md` | 수정 | inventory 채우고 done 전환 |

## AXID Inventory Design

### Naming Convention

기존 패턴 `vision-{surface}-{element}` 유지.

### Identifiers

| AXID | Target View | Purpose |
|------|-------------|---------|
| `vision-chart3d-root` | Chart3DContainerView NavigationStack | container root anchor |
| `vision-chart3d-picker` | Segmented Picker | chart type switcher |
| `vision-chart3d-condition` | ConditionScatter3DView | condition chart content |
| `vision-chart3d-training` | TrainingVolume3DView | training volume chart content |

## Implementation Steps

### Step 1: VisionSurfaceAccessibility에 Chart3D AXID 추가

`VisionSurfaceAccessibility`에 4개 static let 추가.

### Step 2: Chart3DContainerView에 AXID 연결

- NavigationStack에 `vision-chart3d-root`
- Picker에 `vision-chart3d-picker`
- chartContent switch 각 case에 해당 AXID

### Step 3: 자식 뷰에 AXID 연결

- ConditionScatter3DView 루트 VStack에 `vision-chart3d-condition`
- TrainingVolume3DView 루트에 `vision-chart3d-training`

### Step 4: 안정성 테스트 추가

`VisionSurfaceAccessibilityTests`에 chart3D identifier 안정성 테스트 추가.

### Step 5: TODO 088 문서 갱신

체크리스트 완료, inventory/state/deferred 섹션 채우기, status → done.

## Test Strategy

- `VisionSurfaceAccessibilityTests`에서 새 AXID 값이 변경되지 않는지 검증
- AXID uniqueness 검증 (기존 ID와 충돌 없음)
- 빌드 검증: `scripts/build-ios.sh`

## Risks / Edge Cases

- Chart3D는 visionOS 전용 `Chart3D` API 사용 → iOS 빌드에서 컴파일 조건 확인 필요 (이미 DUNEVision 타겟으로 분리되어 있으므로 위험 낮음)
- VisionSurfaceAccessibility는 DUNE 타겟에 있으므로 Chart3D AXID 정의는 iOS 빌드에서도 컴파일됨 (문제 없음 — 단순 String 상수)
