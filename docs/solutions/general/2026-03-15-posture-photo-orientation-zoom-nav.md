---
tags: [posture, image-orientation, avfoundation, cgimage, zoom, navigation, onTapGesture, NavigationLink]
date: 2026-03-15
category: general
status: implemented
---

# Posture Photo: Orientation, Zoom, Navigation Fixes

## Problem

자세 평가 화면에서 3가지 버그 동시 발생:

1. **사진 가로 회전**: 전면 카메라로 촬영한 세로 사진이 가로로 표시됨
2. **확대 불가**: 관절 오버레이가 포함된 사진을 확대해서 볼 수 없음
3. **기록 탭 무반응**: Posture History에서 기록 행을 탭해도 상세 화면으로 이동하지 않음

### 근본 원인

1. **Orientation**: `PostureCaptureService.compressImage()` — `UIImage(cgImage:)` 생성 시 orientation 미지정. 전면 카메라 CGImage는 landscape pixel dimensions에 orientation metadata가 별도로 존재하지만, `UIImage(cgImage:)` init은 `.up`으로 가정하여 가로 표시

2. **Zoom**: 이미지 표시가 `Image(uiImage:).resizable().aspectRatio(contentMode: .fit)` 만 사용. MagnificationGesture 등 확대 기능 없음

3. **Navigation**: `PostureHistoryView.recordRow()`에서 `.onTapGesture` 수식자가 HStack 전체에 무조건 적용되어, `isCompareMode == false`일 때도 탭 이벤트를 가로채서 내부 `NavigationLink`에 전달되지 않음

## Solution

### 1. Image Orientation Fix

`AVCapturePhoto.fileDataRepresentation()` 사용. 이 메서드는 EXIF orientation이 포함된 JPEG를 반환하므로, `UIImage(data:)` 로 디코딩하면 orientation이 자동 적용됨.

```swift
// Delegate: pass raw file data (not compressed) through continuation
let fileData = photo.fileDataRepresentation()
continuation?.resume(returning: (cgImage, fileData))

// detectPose: compress oriented data off the delegate callback
let imageData = if let orientedJPEG {
    compressOrientedData(orientedJPEG)
} else {
    compressImage(image)
}
```

**주의**: 기존 `photo.cgImageRepresentation()` → `UIImage(cgImage:)` 경로는 orientation 메타데이터를 무시. 반드시 `fileDataRepresentation()` → `UIImage(data:)` 경로 사용.

### 2. Zoomable Photo Viewer

`ZoomablePostureImageView` 컴포넌트 생성:
- `SimultaneousGesture(MagnificationGesture, DragGesture)` 조합
- `.onTapGesture(count: 2)` 로 더블탭 줌 토글 (`.simultaneousGesture(TapGesture(count:2))` 사용 금지 — DragGesture와 충돌)
- `.postureImageZoom($item)` ViewModifier로 3개 View에서 재사용

### 3. Navigation Fix

`recordRow()` 구조 변경:
- 공통 수식자(padding, background, contextMenu)를 외부로 추출
- `recordRowContent()` 내부에서만 분기: compare mode → `onTapGesture`, normal → `NavigationLink`
- `.contentShape(Rectangle())` 추가로 패딩 영역 탭 가능

## Prevention

1. **`.onTapGesture` + `NavigationLink` 공존 금지**: `.onTapGesture`는 조건부여도 항상 탭을 가로챔. NavigationLink가 있는 컨테이너에 `.onTapGesture`를 적용하면 NavigationLink가 작동하지 않음
2. **CGImage → UIImage 변환 시 orientation 확인**: `UIImage(cgImage:)` 는 orientation을 `.up`으로 가정. 카메라 캡처 이미지는 반드시 `fileDataRepresentation()` 또는 `UIImage(cgImage:scale:orientation:)` 사용
3. **제스처 조합 패턴**: pinch + drag는 `SimultaneousGesture`, double-tap은 `.onTapGesture(count:)` 수식자 — `.simultaneousGesture(TapGesture())` 사용 금지

## Lessons Learned

- SwiftUI `.onTapGesture`는 guard로 early return해도 gesture recognizer 자체가 이벤트를 소비하므로 하위 `NavigationLink`가 작동하지 않음
- `AVCapturePhoto.cgImageRepresentation()`은 raw pixel buffer를 반환하며 EXIF orientation 미포함 — 전면 카메라에서 landscape pixel로 저장됨
- `SimultaneousGesture`로 합성된 `TapGesture(count:2)`는 `DragGesture`에 의해 suppress됨 — `.onTapGesture(count:)` 수식자가 별도 UIKit recognizer 경로를 사용하여 정상 작동
