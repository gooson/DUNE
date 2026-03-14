---
tags: [posture, vision, 3d-pose, camera, avfoundation]
date: 2026-03-15
category: solution
status: implemented
---

# Apple Vision 3D Pose Detection for Posture Assessment

## Problem

iOS 앱에서 카메라 기반 자세 측정 시스템을 구현해야 함. Apple Vision Framework의 3D Pose API 선택과 올바른 사용 패턴이 필요.

## Solution

### API 선택: VN-prefixed API 사용 (NOT Swift-native)

```swift
// CORRECT: VN-prefixed API
import Vision

let request = VNDetectHumanBodyPose3DRequest()
let handler = VNImageRequestHandler(cgImage: image, options: [:])

// VNImageRequestHandler.perform()은 동기 — DispatchQueue + continuation 필요
try await withCheckedThrowingContinuation { continuation in
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            try handler.perform([request])
            continuation.resume()
        } catch { continuation.resume(throwing: error) }
    }
}

guard let observation = request.results?.first else { throw ... }

// WRONG: Swift-native API (observation 타입의 accessor가 다름)
// let request = DetectHumanBodyPose3DRequest()  // ← 사용 금지
```

### Joint Position 접근

```swift
// VNHumanBodyPose3DObservation.recognizedPoint() 사용
let point = try observation.recognizedPoint(.leftShoulder)
let translation = point.localPosition.columns.3  // simd_float4x4 → SIMD4
let x = translation.x  // meters from root
let y = translation.y
let z = translation.z
```

### Body Height

```swift
// VNHumanBodyPose3DObservation.bodyHeight → Float (meters), NOT Measurement<UnitLength>
if let height = try? observation.bodyHeight,
   height.isFinite, height > 0.5, height < 2.5 {
    bodyHeight = Double(height)
}
```

### AVCapturePhoto → CGImage (Swift 6 Sendable)

```swift
// AVCapturePhoto is NOT Sendable — extract CGImage in delegate callback
private var photoContinuation: CheckedContinuation<CGImage, any Error>?

func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
    if let error {
        photoContinuation?.resume(throwing: error)
    } else if let cgImage = photo.cgImageRepresentation() {
        photoContinuation?.resume(returning: cgImage)  // CGImage is Sendable
    }
    photoContinuation = nil
}
```

### Continuation Race Guard

```swift
// 동시 capturePhoto() 호출 시 continuation 덮어쓰기 방지
func capturePhoto() async throws -> CGImage {
    guard photoContinuation == nil else {
        throw PostureCaptureError.photoCaptureFailed
    }
    return try await withCheckedThrowingContinuation { ... }
}
```

### Image Size for CloudKit

```swift
// 12MP 원본을 1080px로 다운스케일 → CloudKit 1MB 제한 준수
private static let maxImageDimension: CGFloat = 1080

private func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    guard size.width > maxDimension || size.height > maxDimension else { return image }
    let scale = maxDimension / max(size.width, size.height)
    let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
    return image.preparingThumbnail(of: targetSize) ?? image
}
```

## Prevention

1. Vision API 사용 시 항상 VN-prefixed API 사용 여부 확인
2. AVCapturePhoto를 continuation으로 넘기지 말 것 — CGImage 추출 먼저
3. `photoContinuation` 같은 단일 continuation은 nil guard 필수
4. CloudKit 저장 이미지는 반드시 다운스케일 (1080px max)
5. `simd` import는 Domain 허용 목록에 추가 (순수 수학)
