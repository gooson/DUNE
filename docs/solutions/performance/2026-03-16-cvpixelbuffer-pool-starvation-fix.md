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

### 근본 원인 (2단계)

**1차 원인 (3D 파이프라인)**: `RealtimePoseTracker.handleFrame`에서 `CMSampleBuffer`를 `serialQueue.async` 같은 비동기 경계 너머로 넘겼다. 이후 3D 감지를 위한 Task까지 이어지면 `CMSampleBuffer`가 AVCaptureSession의 CVPixelBuffer 풀 버퍼를 더 오래 붙잡게 되고, 해당 버퍼가 Vision 처리 완료 전까지 풀에 반환되지 않음.

**2차 원인 (2D 파이프라인)**: 3D용 late deep-copy 수정 후에도 에러 지속. `captureOutput` 내의 2D `VNImageRequestHandler`가 pool-backed buffer를 직접 참조하여 `perform()` 중 Vision 내부 YUV→BGRA 변환 시 같은 풀 고갈 발생. 실시간 dual pipeline(2D+3D)이 추가되면서 callback당 pool buffer 보유 시간이 증가한 것이 근본 원인.

카메라 풀은 3-5개 버퍼만 보유. 30fps 전달 중 1개가 장시간 잠기면 풀이 고갈되어 Vision 내부 ML 파이프라인이 BGRA 변환 버퍼를 할당하지 못함.

## Solution

### 변경 파일

| File | Change |
|------|--------|
| `PostureCaptureService.swift` | `captureOutput`에서 `CVPixelBuffer`를 deep-copy한 뒤 callback으로 전달 |
| `RealtimePoseTracker.swift` | `handleFrame`이 `CMSampleBuffer` 대신 copied buffer만 받아 3D Task를 시작 |

### 핵심 패턴: Early Deep-Copy

```swift
// Before (1차 수정): 2D detection 후 3D용으로만 late copy → 2D detection이 여전히 pool buffer 사용
let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer /* pool-backed */)
try handler.perform([bodyPoseRequest])  // Vision holds pool buffer during ML inference
// ... luminance, guidance ...
let copiedBuffer: CVPixelBuffer? = if !keypoints.isEmpty {
    Self.copyPixelBuffer(pixelBuffer)  // Late copy for 3D only
} else { nil }

// After (2차 수정): captureOutput 시작부에서 즉시 deep-copy → pool buffer 즉시 해제
guard let poolBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
guard let pixelBuffer = Self.copyPixelBuffer(poolBuffer) else { return }
// poolBuffer is released when sampleBuffer goes out of scope — pool freed immediately.

let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer /* heap copy */)
try handler.perform([bodyPoseRequest])  // Vision uses independent copy
// ... luminance(from: pixelBuffer), guidance ...
onRealtimeFrame?(keypoints, keypoints.isEmpty ? nil : pixelBuffer)  // Same copy reused for 3D
```

### copyPixelBuffer 구현

- `CVPixelBufferCreate`로 독립 버퍼 생성 (CPU-only heap, IOSurface 없음)
- planar (420YpCbCr) + interleaved 포맷 모두 지원
- `memcpy`로 plane별 데이터 복사
- 실패 시 해당 프레임 전체 건너뜀 (10fps 중 1프레임 유실은 무해)

## Prevention

### 패턴: AVCaptureSession 버퍼 사용 원칙

- **pool-backed buffer를 synchronous Vision detection에도 직접 전달하지 않음** — `perform()` 중 내부 변환이 pool을 추가 소모
- **`captureOutput` 시작부에서 즉시 deep-copy** 후 모든 후속 작업에 copy 사용
- **절대 `CMSampleBuffer`를 어떤 비동기 queue/task/closure에도 캡처하지 않음**
- `CVPixelBuffer` 딥카피 또는 `CGImage` 변환 후 전달

### 패턴: guard-return 대 if-let 선택

- delegate 콜백에서 `guard-return`은 **후속 로직도 함께 건너뜀**
- 부분 실패 허용이 필요하면 `if-let` 체인으로 해당 블록만 건너뛰기

## Lessons Learned

1. `CMSampleBuffer`는 AVCaptureSession의 풀 버퍼를 보유한다는 것을 항상 인지해야 함
2. 시뮬레이터에서는 재현되지 않는 실기기 전용 버그 — 카메라 관련 변경은 반드시 실기기 테스트
3. Vision 프레임워크의 `mlImage buffer` 에러는 메모리 부족이 아닌 **버퍼 풀 고갈** 시그널
