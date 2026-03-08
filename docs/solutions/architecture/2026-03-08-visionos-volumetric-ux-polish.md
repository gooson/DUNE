---
tags: [visionOS, HIG, ornament, volumetric, RealityKit, gesture, empty-state]
date: 2026-03-08
category: solution
status: implemented
---

# visionOS Volumetric Window UX Polish

## Problem

visionOS 볼류메트릭 윈도우에서 2D UI 컨트롤(Picker, 메트릭 카드, 근육 리스트)이 3D RealityKit 콘텐츠와 혼재되어 HIG 위반. 추가로 3D 씬 간 제스처 패턴 불일치, 빈 상태 메시지 비일관, 타이포그래피 크기 문제 존재.

## Solution

### 1. Ornament 분리 패턴

볼류메트릭 윈도우에서 2D 컨트롤은 `.ornament()` modifier로 분리:

```swift
// 하단: Scene Picker
.ornament(attachmentAnchor: .scene(.bottom)) {
    Picker("Scene", selection: $selectedScene) { ... }
    .pickerStyle(.segmented)
    .glassBackgroundEffect()
}

// 우측: 메트릭/근육 정보 패널
.ornament(attachmentAnchor: .scene(.trailing)) {
    VStack { metricStrip; muscleStrip }
    .glassBackgroundEffect()
}
```

**핵심**: `.glassBackgroundEffect()` 사용으로 visionOS 네이티브 유리 재질 적용.

### 2. DragGesture 회전 표준화

3D 씬(HeartRateOrb, TrainingVolumeBlocks, BodyHeatmap)에 동일한 드래그 회전 패턴 적용:

```swift
@State private var yaw: Float = 0     // 초기값은 씬별 상이
@State private var pitch: Float = 0
@State private var dragStartYaw: Float = 0
@State private var dragStartPitch: Float = 0

private var rotationGesture: some Gesture {
    DragGesture(minimumDistance: 2)
        .onChanged { value in
            yaw = dragStartYaw + Float(value.translation.width) * 0.008
            pitch = (dragStartPitch + Float(value.translation.height) * 0.004)
                .clamped(to: -0.48...0.18)
        }
        .onEnded { _ in
            dragStartYaw = yaw
            dragStartPitch = pitch
        }
}
```

**중요**: `Float.clamped(to:)` 는 `Domain/Extensions/Comparable+Clamped.swift`의 `Comparable` 확장을 사용. 씬별 private extension 복사 금지.

### 3. 빈 상태 메시지 통일

모든 visionOS 뷰에서 동일한 3-tier 빈 상태 구조:

```swift
VStack(spacing: 8) {
    Image(systemName: "chart.bar.xaxis") // 컨텍스트에 맞는 아이콘
        .font(.largeTitle)
    Text("No data available")
        .font(.subheadline)
    Text("Start tracking on iPhone or Apple Watch.")
        .font(.callout)
        .foregroundStyle(.secondary)
}
```

### 4. 공간 타이포그래피

visionOS에서 `.caption` (11pt)은 팔 길이 거리에서 가독성 불량. `.callout` (14pt)을 공간 최소 크기로 사용.

## Prevention

- visionOS 볼류메트릭 윈도우에 2D 컨트롤 추가 시 항상 `.ornament()` 사용
- 새 3D RealityKit 씬 추가 시 DragGesture 회전 표준 패턴 적용
- `Float.clamped(to:)` 사용 시 `Comparable+Clamped.swift` 확인 — private extension 복사 금지
- visionOS 빈 상태는 아이콘 + 메시지 + 안내 3-tier 구조 준수
- visionOS 텍스트 크기 `.callout` 이상 사용 (`.caption` 금지)
