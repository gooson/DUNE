---
tags: [posture, avfoundation, cvpixelbuffer, vision, mlimage, performance]
date: 2026-03-16
category: plan
status: approved
---

# Fix: mlImage Buffer Pool Starvation on Real Device

## Problem

실기기에서 자세교정 사진 촬영 시 `Could not create mlImage buffer of type kCVPixelFormatType_32BGRA` 에러가 반복 발생하여 카메라가 작동하지 않음.

### Root Cause

`RealtimePoseTracker.handleFrame`에서 3D 포즈 감지를 비동기 Task로 실행할 때, `CMSampleBuffer`를 Task 클로저에 캡처함. `CMSampleBuffer`는 AVCaptureSession의 **CVPixelBuffer 풀**에서 할당된 버퍼를 보유하고 있어, 3D 감지가 완료될 때까지 (50-250ms) 해당 버퍼가 풀에 반환되지 않음.

카메라가 30fps로 새 프레임을 전달하는 동안 풀 버퍼가 고갈되면, Vision 프레임워크 내부에서 ML 추론용 BGRA 변환 버퍼를 할당하지 못함.

### 참조

- `docs/solutions/architecture/2026-03-16-realtime-dual-pipeline-posture.md`: 듀얼 파이프라인 구조

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Data/Services/RealtimePoseTracker.swift` | CVPixelBuffer 딥카피 추가, perform3DDetection 시그니처 변경 |
| `DUNE/Data/Services/PostureCaptureService.swift` | detectPoseFromVideoFrame 시그니처를 CVPixelBuffer로 변경 |

## Implementation Steps

### Step 1: PostureCaptureService.detectPoseFromVideoFrame 시그니처 변경

- `CMSampleBuffer` → `CVPixelBuffer` 파라미터로 변경
- `CMSampleBufferGetImageBuffer` 호출 제거 (caller 책임)

### Step 2: RealtimePoseTracker에 copyPixelBuffer 추가

- `CVPixelBufferCreate`로 독립 버퍼 생성
- planar (420YpCbCr) + interleaved 포맷 모두 지원하는 딥카피
- memcpy로 plane별 데이터 복사

### Step 3: handleFrame에서 3D 감지 시 복사된 버퍼 사용

- `CMSampleBufferGetImageBuffer` → `copyPixelBuffer` → Task에 복사본만 전달
- 원본 CMSampleBuffer는 handleFrame 종료 시 즉시 풀에 반환

## Test Strategy

- 빌드 검증: `scripts/build-ios.sh`
- 실기기 테스트: 자세교정 카메라에서 mlImage 에러 없이 3D 감지 작동 확인
- 유닛 테스트: copyPixelBuffer는 순수 C API 기반이라 mock 불가, 빌드 검증으로 대체

## Risk / Edge Cases

- **메모리 증가**: 매 3D 감지마다 풀사이즈 버퍼 복사 (4fps × ~12MB photo preset = ~48MB/s peak). 복사 후 즉시 해제되므로 steady-state는 1개 버퍼 추가 (~12MB)
- **copyPixelBuffer 실패**: CVPixelBufferCreate 실패 시 3D 감지를 건너뜀 (2D 파이프라인은 영향 없음)
