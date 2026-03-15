---
tags: [posture, image, orientation, zoom, navigation]
date: 2026-03-15
category: plan
status: draft
---

# Posture Photo Fixes: Orientation, Zoom, Navigation

## Problem Statement

자세 평가 화면에서 3가지 버그:
1. 사진이 가로로 회전되어 표시됨
2. 사진 확대(줌)가 안 됨
3. Posture History에서 기록 탭해도 반응 없음

## Root Causes

### 1. Image Orientation
- `PostureCaptureService.compressImage()`: `UIImage(cgImage:)` 생성 시 orientation 미지정
- Front camera CGImage는 pixel buffer가 landscape로 저장되고 orientation metadata로 portrait 표시
- `UIImage(cgImage:)` init은 orientation을 `.up`으로 가정 → 가로 표시

### 2. No Zoom
- `PostureDetailView`, `PostureResultView`에서 `Image(uiImage:).resizable().aspectRatio(contentMode: .fit)` 사용
- MagnificationGesture, 풀스크린 뷰 등 확대 기능 없음

### 3. Navigation Broken
- `PostureHistoryView.recordRow()` line 309: `.onTapGesture` modifier가 HStack 전체에 적용
- `isCompareMode == false`일 때도 `.onTapGesture`가 탭 이벤트를 가로채서 내부 `NavigationLink`에 전달 안 됨

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Data/Services/PostureCaptureService.swift` | Fix image orientation in compressImage |
| `DUNE/Presentation/Posture/PostureHistoryView.swift` | Fix .onTapGesture blocking NavigationLink |
| `DUNE/Presentation/Posture/PostureDetailView.swift` | Add fullscreen zoomable photo sheet |
| `DUNE/Presentation/Posture/PostureResultView.swift` | Add fullscreen zoomable photo sheet |
| `DUNE/Presentation/Posture/Components/ZoomablePostureImageView.swift` | New: shared zoomable image component |

## Implementation Steps

### Step 1: Fix Image Orientation
- `compressImage(_:)`: `AVCapturePhoto`에서 orientation 정보를 함께 전달
- `UIImage(cgImage:scale:orientation:)` 사용하여 올바른 orientation 적용
- 기존 저장된 데이터는 JPEG이므로 EXIF orientation이 이미 baked-in → 신규 캡처만 수정

### Step 2: Fix Navigation (onTapGesture blocking)
- `.onTapGesture`를 `isCompareMode` 조건으로 감싸거나
- `recordRow` 구조 변경: compare mode일 때만 onTapGesture 적용

### Step 3: Add Zoomable Photo View
- `ZoomablePostureImageView`: 풀스크린 sheet로 사진 확대 가능
- MagnificationGesture + DragGesture 조합
- JointOverlay 포함 상태로 확대
- PostureDetailView, PostureResultView에서 이미지 탭 시 sheet 표시

## Test Strategy

- 빌드 성공 확인
- 기존 JPEG 데이터 호환성 (이미 저장된 사진은 orientation 변경 불필요)

## Risks

- 기존 저장된 사진 데이터의 orientation이 이미 잘못 baked-in 된 경우 → 소급 수정 불가 (신규 캡처만 개선)
- MagnificationGesture와 ScrollView 간 제스처 충돌 가능성
