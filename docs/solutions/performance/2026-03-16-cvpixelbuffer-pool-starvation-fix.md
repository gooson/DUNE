---
tags: [posture, avfoundation, cvpixelbuffer, vision, mlimage, buffer-pool, camera, performance, cgimage]
date: 2026-03-16
category: solution
status: implemented
---

# CVPixelBuffer Pool Starvation → mlImage Buffer Creation Failure

## Problem

실기기에서 자세교정 카메라 실행 시 `Could not create mlImage buffer of type kCVPixelFormatType_32BGRA` 에러가 반복 발생하여 3D 포즈 감지 실패.

### 증상

- 카메라 프리뷰는 표시되나 3D 포즈 감지 실패
- Xcode 콘솔에 `FigXPCUtilities err=-17281`, `Could not create mlImage buffer` 반복 출력
- 시뮬레이터에서는 발생하지 않음 (시뮬레이터는 다른 카메라 파이프라인 사용)

### 근본 원인

Dual pipeline(2D+3D)이 추가되면서 `CVPixelBuffer`가 비동기 경계를 넘어 3D Task까지 도달. AVCaptureSession의 pool buffer(3-5개)가 Vision ML 파이프라인에 의해 장시간 잠겨 풀이 고갈됨.

**CVPixelBuffer 딥카피로는 불충분**: 딥카피한 CVPixelBuffer도 `VNImageRequestHandler`에 전달하면 Vision 내부 ML 파이프라인이 추가 버퍼를 할당하려 시도하여 여전히 경합 발생. 2D(videoDataQueue) + 3D(global queue) 동시 실행 시 Vision의 내부 버퍼 풀이 고갈됨.

**CGImage만이 풀 의존성 제로**: CGImage는 heap-allocated 독립 이미지로, AVCaptureSession 버퍼 풀과 완전히 분리.

## Solution

### 변경 파일

| File | Change |
|------|--------|
| `PostureCaptureService.swift` | 2D detection은 pool buffer 직접 사용, 3D용으로 `CIContext.createCGImage`로 CGImage 생성 |
| `PostureCaptureService.swift` | `onRealtimeFrame` 콜백 타입을 `CVPixelBuffer?` → `CGImage?`로 변경 |
| `PostureCaptureService.swift` | `detectPoseFromVideoFrame`이 `CGImage`를 받아 기존 `detectPose(from:)` 위임 |
| `RealtimePoseTracker.swift` | `SendablePixelBuffer` 래퍼 제거, `CGImage` 직접 사용 (이미 Sendable) |

### 핵심 패턴: Pool Buffer → CGImage 분리

```swift
// captureOutput — pool buffer는 이 메서드 내에서만 사용
guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

// 2D detection: pool buffer 직접 사용 (synchronous, 반환 시 즉시 해제)
let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
try handler.perform([bodyPoseRequest])
// ... keypoints, luminance, guidance ...

// 3D pipeline: CGImage로 변환 (pool 의존성 제로)
var cgImageFor3D: CGImage?
if !keypoints.isEmpty, onRealtimeFrame != nil {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    cgImageFor3D = Self.ciContext.createCGImage(ciImage, from: ciImage.extent)
}
// pixelBuffer는 sampleBuffer scope 종료 시 pool에 반환

onRealtimeFrame?(keypoints, cgImageFor3D)
```

### 시도했으나 실패한 접근

1. **Late deep-copy (3D only)**: 2D detection이 여전히 pool buffer 사용 → 풀 고갈
2. **Early deep-copy (모든 작업)**: CVPixelBuffer 딥카피도 Vision 내부에서 추가 버퍼 경합 발생

## Prevention

### 패턴: AVCaptureSession 버퍼 사용 원칙

- **pool buffer는 `captureOutput` 스코프 내에서만 사용** — synchronous 작업에 한정
- **비동기 경계를 넘기는 데이터는 반드시 CGImage로 변환** — `CIContext.createCGImage` 사용
- **절대 `CMSampleBuffer`/`CVPixelBuffer`를 어떤 비동기 queue/task/closure에도 캡처하지 않음**
- **CVPixelBuffer 딥카피도 Vision과 동시 사용 시 풀 고갈 가능** — CGImage가 유일한 안전 경로

### 패턴: guard-return 대 if-let 선택

- delegate 콜백에서 `guard-return`은 **후속 로직도 함께 건너뜀**
- 부분 실패 허용이 필요하면 `if-let` 체인으로 해당 블록만 건너뛰기

## Lessons Learned

1. `CMSampleBuffer`는 AVCaptureSession의 풀 버퍼를 보유한다는 것을 항상 인지해야 함
2. CVPixelBuffer 딥카피는 Vision 동시 실행 환경에서 불충분 — CGImage만 풀 독립적
3. 시뮬레이터에서는 재현되지 않는 실기기 전용 버그 — 카메라 관련 변경은 반드시 실기기 테스트
4. Vision 프레임워크의 `mlImage buffer` 에러는 메모리 부족이 아닌 **버퍼 풀 고갈** 시그널
5. `CIContext.createCGImage`는 GPU→CPU 전송이지만 일반적으로 <5ms로 30fps에 무해
