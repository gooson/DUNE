---
tags: [posture, avfoundation, cvpixelbuffer, vision, mlimage, buffer-pool, camera, performance]
date: 2026-03-16
category: solution
status: implemented
---

# CVPixelBuffer Pool Starvation → mlImage Buffer Creation Failure

## Problem

실기기에서 자세교정 카메라 실행 시 `Could not create mlImage buffer of type kCVPixelFormatType_32BGRA` 에러가 반복 발생하여 사진 촬영 불가.

### 증상

- 카메라 프리뷰는 표시되나 3D 포즈 감지 실패
- Xcode 콘솔에 `FigXPCUtilities err=-17281`, `Could not create mlImage buffer` 반복 출력
- 시뮬레이터에서는 발생하지 않음 (시뮬레이터는 다른 카메라 파이프라인 사용)

### 근본 원인

`RealtimePoseTracker.handleFrame`에서 `CMSampleBuffer`를 `serialQueue.async` 같은 비동기 경계 너머로 넘겼다. 이후 3D 감지를 위한 Task까지 이어지면 `CMSampleBuffer`가 AVCaptureSession의 CVPixelBuffer 풀 버퍼를 더 오래 붙잡게 되고, 해당 버퍼가 Vision 처리 완료 전까지 풀에 반환되지 않음.

카메라 풀은 3-5개 버퍼만 보유. 30fps 전달 중 1개가 장시간 잠기면 풀이 고갈되어 Vision 내부 ML 파이프라인이 BGRA 변환 버퍼를 할당하지 못함.

## Solution

### 변경 파일

| File | Change |
|------|--------|
| `PostureCaptureService.swift` | `captureOutput`에서 `CVPixelBuffer`를 deep-copy한 뒤 callback으로 전달 |
| `RealtimePoseTracker.swift` | `handleFrame`이 `CMSampleBuffer` 대신 copied buffer만 받아 3D Task를 시작 |

### 핵심 패턴

```swift
// Before: CMSampleBuffer가 queued closure / Task에 캡처 → 풀 고갈
serialQueue.async {
    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    self.pending3DTask = Task {
        await self?.perform3DDetection(sampleBuffer)
    }
}

// After: camera callback에서 deep-copy한 버퍼만 후속 파이프라인으로 전달
let copiedBuffer: CVPixelBuffer? = if !keypoints.isEmpty {
    Self.copyPixelBuffer(pixelBuffer)
} else {
    nil
}
onRealtimeFrame?(keypoints, copiedBuffer)

private func handleFrame(keypoints: [(String, CGPoint)], copiedBuffer: CVPixelBuffer?) {
    serialQueue.async {
        if !is3DInFlight,
           let buffer = copiedBuffer {
            self.pending3DTask = Task {
                await self?.perform3DDetection(buffer)
            }
        }
    }
}
```

### copyPixelBuffer 구현

- `CVPixelBufferCreate`로 독립 버퍼 생성 (IOSurface backing 포함)
- planar (420YpCbCr) + interleaved 포맷 모두 지원
- `memcpy`로 plane별 데이터 복사
- 실패 시 3D 감지만 건너뜀 (2D 파이프라인 + UI 업데이트 영향 없음)

## Prevention

### 패턴: AVCaptureSession 버퍼를 비동기 작업에 전달할 때

- **절대 `CMSampleBuffer`를 어떤 비동기 queue/task/closure에도 캡처하지 않음**
- 필요한 데이터를 **async 경계 전에 복사**한 후 원본은 즉시 해제
- `CVPixelBuffer` 딥카피 또는 `CGImage` 변환 후 전달

### 패턴: guard-return 대 if-let 선택

- delegate 콜백에서 `guard-return`은 **후속 로직도 함께 건너뜀**
- 부분 실패 허용이 필요하면 `if-let` 체인으로 해당 블록만 건너뛰기

## Lessons Learned

1. `CMSampleBuffer`는 AVCaptureSession의 풀 버퍼를 보유한다는 것을 항상 인지해야 함
2. 시뮬레이터에서는 재현되지 않는 실기기 전용 버그 — 카메라 관련 변경은 반드시 실기기 테스트
3. Vision 프레임워크의 `mlImage buffer` 에러는 메모리 부족이 아닌 **버퍼 풀 고갈** 시그널
