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

`RealtimePoseTracker.handleFrame`에서 3D 감지를 비동기 Task로 실행할 때 `CMSampleBuffer`를 클로저에 캡처. `CMSampleBuffer`는 AVCaptureSession의 CVPixelBuffer 풀 버퍼를 보유하므로, 3D 감지 완료까지 (50-250ms) 풀에 반환되지 않음.

카메라 풀은 3-5개 버퍼만 보유. 30fps 전달 중 1개가 장시간 잠기면 풀이 고갈되어 Vision 내부 ML 파이프라인이 BGRA 변환 버퍼를 할당하지 못함.

## Solution

### 변경 파일

| File | Change |
|------|--------|
| `RealtimePoseTracker.swift` | `copyPixelBuffer` 딥카피 + `if-let` 체인으로 안전 처리 |
| `PostureCaptureService.swift` | `detectPoseFromVideoFrame` 시그니처를 `CVPixelBuffer`로 변경 |

### 핵심 패턴

```swift
// Before: CMSampleBuffer가 Task에 캡처 → 풀 고갈
self.pending3DTask = Task {
    await self?.perform3DDetection(sampleBuffer)  // sampleBuffer holds pool buffer
}

// After: 복사본만 Task에 전달 → 원본 즉시 반환
if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
   let copiedBuffer = Self.copyPixelBuffer(pixelBuffer) {
    self.pending3DTask = Task {
        await self?.perform3DDetection(copiedBuffer)  // independent buffer
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

- **절대 `CMSampleBuffer`를 비동기 Task/closure에 캡처하지 않음**
- 필요한 데이터를 복사한 후 원본은 즉시 해제
- `CVPixelBuffer` 딥카피 또는 `CGImage` 변환 후 전달

### 패턴: guard-return 대 if-let 선택

- delegate 콜백에서 `guard-return`은 **후속 로직도 함께 건너뜀**
- 부분 실패 허용이 필요하면 `if-let` 체인으로 해당 블록만 건너뛰기

## Lessons Learned

1. `CMSampleBuffer`는 AVCaptureSession의 풀 버퍼를 보유한다는 것을 항상 인지해야 함
2. 시뮬레이터에서는 재현되지 않는 실기기 전용 버그 — 카메라 관련 변경은 반드시 실기기 테스트
3. Vision 프레임워크의 `mlImage buffer` 에러는 메모리 부족이 아닌 **버퍼 풀 고갈** 시그널
