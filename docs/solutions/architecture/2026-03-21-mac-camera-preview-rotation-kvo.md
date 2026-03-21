---
tags: [camera, mac, rotation, KVO, RotationCoordinator, preview, posture, designed-for-ipad]
date: 2026-03-21
category: architecture
status: implemented
related_files:
  - DUNE/Presentation/Posture/PostureCaptureView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-16-posture-orientation-coordinate-contract.md
---

# Solution: Mac Camera Preview 90° Rotation Fix (KVO Observation)

## Problem

Mac에서 자세 평가 카메라 프리뷰가 90° 회전되어 표시됨. iOS에서는 정상 동작.

### Symptoms

- Mac (Designed for iPad) 환경에서 FaceTime 카메라 프리뷰가 세로로 눕혀져 보임
- iOS에서는 동일 코드가 정상 동작

### Root Cause

`CameraPreviewUIView.updatePreview()`가 `RotationCoordinator.videoRotationAngleForHorizonLevelPreview`를 **한 번만** 읽고 설정하는 구조.

iOS에서는 기기 회전 → `UIDevice.orientationDidChangeNotification` → SwiftUI state 변경 → `updateUIView` 재호출로 rotation이 갱신되지만, Mac에서는:

1. `UIDevice.current.orientation`이 항상 `.unknown` → 재호출 트리거 없음
2. `makeUIView` 시점에 `previewLayer.connection`이 nil → early return으로 rotation 미적용
3. RotationCoordinator가 previewLayer 프레임 안정화 후 정확한 각도를 제공하더라도 읽는 시점이 이미 지남

## Solution

Apple의 AVCam 샘플 패턴대로 `videoRotationAngleForHorizonLevelPreview`를 KVO로 관찰하여 변경 시 preview connection에 자동 반영.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `PostureCaptureView.swift` | `CameraPreviewUIView`에 `rotationObservation: NSKeyValueObservation?` 추가 | KVO로 rotation angle 관찰 |
| `PostureCaptureView.swift` | `onPreviewRotationAngleChange`를 stored property로 변경 | KVO 콜백에서 접근 가능하도록 |
| `PostureCaptureView.swift` | `applyRotationAngle(_:)` 메서드 추출 | KVO 콜백과 초기값 설정에서 공유 |

### Key Code

```swift
rotationObservation = rotationCoordinator?.observe(
    \.videoRotationAngleForHorizonLevelPreview,
    options: [.new, .initial]
) { [weak self] _, change in
    let angle = change.newValue ?? 0
    DispatchQueue.main.async { [weak self] in
        self?.applyRotationAngle(angle)
    }
}
```

## Prevention

### Checklist

- [ ] `AVCaptureVideoPreviewLayer` rotation angle을 한 번만 읽고 설정하는 패턴 사용 금지
- [ ] RotationCoordinator의 rotation angle은 반드시 KVO로 관찰하여 변경 시 자동 반영
- [ ] Mac (Designed for iPad) 환경에서 카메라 관련 변경 시 수동 테스트 필수

### Rule

카메라 프리뷰 rotation은 KVO observation 패턴을 사용한다. 일회성 읽기는 Mac에서 동작하지 않는다.

## Lessons Learned

- "Designed for iPad" on Mac에서 `UIDevice.current.orientation`은 항상 `.unknown`이므로, iOS에서 orientation 변경에 의존하는 UI 갱신 패턴은 Mac에서 동작하지 않는다
- Apple의 AVCam 샘플이 KVO를 사용하는 이유: RotationCoordinator의 angle은 비동기적으로 안정화되므로 생성 직후 읽은 값이 정확하지 않을 수 있다
- Swift 6 strict concurrency에서 KVO 콜백의 coordinator 파라미터를 직접 사용하면 `sending risks causing data races` 에러가 발생한다 — `change.newValue`에서 값을 복사해야 한다
