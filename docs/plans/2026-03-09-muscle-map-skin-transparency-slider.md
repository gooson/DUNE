---
tags: [muscle-map, 3d, realitykit, skin, transparency, slider, usdz]
date: 2026-03-09
category: plan
status: draft
---

# Plan: 피부 투명도 슬라이더 (#097)

## Problem Statement

현재 MuscleMap3DView의 `body_shell` 엔티티는 고정 opacity(dark 0.05 / light 0.06)로 렌더링되어 사용자가 피부(스킨) 레이어의 가시성을 제어할 수 없다. 슬라이더로 투명도를 조절하여 근육 위에 피부를 보이거나 숨길 수 있어야 한다.

## Scope

- MuscleMap3DView에 피부 투명도 슬라이더 UI 추가
- MuscleMap3DScene의 shell material opacity를 동적으로 조절
- visionOS는 별도 `applyShellMaterials()` 사용 — 이번 변경 범위 아님

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | `@State shellOpacity` 추가, 슬라이더 UI, Viewer에 전달 |
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | `updateShellMaterials` → opacity 파라미터화, `updateVisuals` 시그니처 변경 |
| `Shared/Resources/Localizable.xcstrings` | "Skin" 키 en/ko/ja 번역 추가 |

## Implementation Steps

### Step 1: MuscleMap3DScene — shell opacity 파라미터화

**변경**: `updateShellMaterials(colorScheme:)` → `updateShellMaterials(colorScheme:shellOpacity:)`

- `shellOpacity` 파라미터(Float, 0...1)를 받아 `withAlphaComponent(CGFloat(shellOpacity))` 적용
- `updateVisuals`에도 `shellOpacity` 파라미터 추가하여 내부에서 `updateShellMaterials`에 전달
- dark/light 모드에 따른 tint 색상은 유지 (white / black), alpha만 파라미터화

**검증**: 컴파일 오류 없음

### Step 2: MuscleMap3DViewer — opacity 전달

**변경**: `MuscleMap3DViewer`에 `shellOpacity` 프로퍼티 추가

- `let shellOpacity: Float` 프로퍼티 추가
- `refreshScene()`에서 `scene.updateVisuals(... shellOpacity: shellOpacity)` 전달

**검증**: 컴파일 오류 없음, 기존 동작 유지

### Step 3: MuscleMap3DView — 슬라이더 UI 추가

**변경**: mode picker 아래, viewer 위에 슬라이더 배치

```swift
@State private var shellOpacity: Double = 0.06

// UI: Slider with "Skin" label
HStack(spacing: DS.Spacing.sm) {
    Label("Skin", systemImage: "eye")
        .font(.caption)
        .foregroundStyle(DS.Color.textSecondary)
    Slider(value: $shellOpacity, in: 0...0.5)
        .tint(DS.Color.activity)
}
```

- 범위: 0 (완전 투명) ~ 0.5 (반투명 피부). 1.0까지 가면 근육이 완전히 가려져 무의미
- 기본값: 0.06 (현재 동작과 동일)
- `Float(shellOpacity)`로 변환하여 Viewer에 전달

**검증**: 슬라이더 조작 시 shell opacity 실시간 변경

### Step 4: Localization — xcstrings 업데이트

- "Skin" 키 추가: en "Skin", ko "피부", ja "スキン"

**검증**: 3개 언어 키 존재

## Test Strategy

- **테스트 면제**: SwiftUI View body 변경 (UI 테스트 영역)
- **수동 검증**: 슬라이더 0 → shell 비표시, 슬라이더 max → shell 반투명, 기본값 → 현재 동작 동일
- **기존 코드 영향**: visionOS `BodyHeatmapSceneView`는 자체 `applyShellMaterials()` 사용 → 영향 없음

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| visionOS 빌드 깨짐 | `updateVisuals` 시그니처 변경 → visionOS 호출부도 업데이트 필요. 확인 후 처리 |
| slider 기본값 변경 시 기존 UX 영향 | 기본값 0.06 유지하여 현재 동작과 동일 |
| shell이 0 opacity일 때 collision 이슈 | shell은 hit testing에 사용되지 않음 (muscle 엔티티가 개별 collision) → 없음 |
