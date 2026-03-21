---
tags: [posture, camera, front-camera, truedepth, vision, buffer-pool, iosurface, cgimage, performance]
date: 2026-03-21
category: performance
status: implemented
severity: critical
related_files:
  - DUNE/Data/Services/PostureCaptureService.swift
  - .claude/rules/performance-patterns.md
---

# Solution: 전면 카메라(TrueDepth) 자세교정 Vision 실패 — CGImage 기반 탈풀화

## Problem

전면 카메라(TrueDepth)에서 자세교정 기능(2D/3D body pose detection)이 실패.
후면 카메라에서는 정상 동작.

### 증상

- 전면 카메라에서 VNDetectHumanBodyPoseRequest 실행 시 Vision 내부 에러
- "Could not create mlImage buffer" 에러 시그널
- 2D skeleton overlay 표시 안 됨
- 3D 자세 점수 업데이트 안 됨

### 근본 원인

TrueDepth 카메라(전면)의 depth sensor (dot projector, IR camera, flood illuminator)가 GPU/buffer 공유 리소스를 점유.

`VNImageRequestHandler(cvPixelBuffer: poolBuffer)` 경로에서:
1. pool buffer는 IOSurface 기반 (GPU-accessible shared memory)
2. Vision ML inference가 추가 내부 버퍼를 같은 GPU memory pool에서 할당 시도
3. 후면 카메라: depth sensor 없음 → GPU buffer 공간 충분 → 할당 성공
4. 전면 카메라: TrueDepth depth sensor가 공유 리소스 점유 → 할당 실패

### 이전 시도

| 접근 | 결과 |
|------|------|
| BGRA 포맷 강제 (YUV→BGRA 변환 제거) | 부분 해결 — 변환 버퍼 할당은 제거했으나 ML inference 버퍼는 여전히 경쟁 |
| CVPixelBuffer 딥카피 | 불충분 — Vision 내부 ML 파이프라인이 IOSurface 경유 가능 |
| CIContext.createCGImage (모든 프레임) | 동작하나 GPU round-trip 오버헤드로 10fps에서 성능 문제 |

## Solution

**CPU memcpy 기반 CGImage 생성으로 Vision을 카메라 IOSurface pool에서 완전 분리.**

### 핵심 변경

1. `createCGImageFromBGRABuffer()` static method 추가:
   - CVPixelBuffer lock → `Data(bytes:count:)` memcpy → unlock → CGDataProvider → CGImage
   - CGImage는 heap memory에 존재 → IOSurface 의존성 제로
   - 720p BGRA ≈ 3.6MB memcpy ≈ 0.4ms (CIContext GPU round-trip 불필요)

2. `captureOutput`에서 `VNImageRequestHandler(cvPixelBuffer:)` → `VNImageRequestHandler(cgImage:)` 전환

3. 동일 CGImage를 2D detection과 3D sampling에 공유 (3D는 ~4fps throttle 유지)

4. Static 캐싱: `fallbackCIContext`, `bgraColorSpace`

### 최적화 포인트

- CGImage 생성은 semaphore 획득 후 실행 (dropped frame에서 불필요한 memcpy 방지)
- 3D sampling은 `threeDSamplingInterval` (0.25s)로 throttle 유지
- Non-BGRA fallback은 static CIContext 사용

## Prevention

### 규칙 (performance-patterns.md에 반영)

- pool buffer를 Vision에 직접 전달 금지 — 항상 CGImage 변환 후 전달
- 전면 카메라(TrueDepth)는 BGRA 포맷만으로 불충분 — CGImage 필수
- CGImage 생성은 CPU memcpy 기반 (CIContext GPU round-trip 회피)
- CIContext, CGColorSpace 등 heavyweight 객체는 반드시 static 캐싱

### 체크리스트

- [ ] Vision handler에 CVPixelBuffer를 직접 전달하지 않았는가?
- [ ] CGImage 생성이 semaphore 획득 후 실행되는가? (wasted memcpy 방지)
- [ ] CIContext, CGColorSpace 등이 per-call이 아닌 static 캐싱인가?
- [ ] 3D sampling rate가 원래 의도한 4fps를 유지하는가?

## Lessons Learned

- IOSurface 기반 pool buffer와 Vision ML inference의 리소스 경쟁은 포맷 변환만으로 해결되지 않음
- CPU memcpy의 비용(0.4ms)은 GPU 리소스 경쟁의 비용(전면 카메라 완전 실패)보다 훨씬 낮음
- CIContext.createCGImage는 GPU round-trip이므로 고빈도 경로에서 CPU memcpy가 더 적합
- heavyweight 객체(CIContext, CGColorSpace)의 per-call 생성은 성능 리뷰에서 반드시 잡아야 함
