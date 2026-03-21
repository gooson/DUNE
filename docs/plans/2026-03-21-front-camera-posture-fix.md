---
tags: [posture, camera, front-camera, truedepth, vision, buffer-pool]
date: 2026-03-21
category: plan
status: draft
---

# Plan: 전면 카메라 자세교정 실패 수정

## Problem Statement

전면 카메라(TrueDepth)에서 자세교정(realtime + capture) 실패. 후면 카메라는 정상 동작.

### Root Cause Analysis

1. **현재 2D detection path**: `captureOutput` → `VNImageRequestHandler(cvPixelBuffer: poolBuffer)` — IOSurface 기반 pool buffer를 Vision에 직접 전달
2. **TrueDepth 리소스 경쟁**: TrueDepth 카메라(전면)의 depth sensor가 GPU/buffer 공유 리소스를 점유. Vision의 ML 추론 시 추가 내부 버퍼 할당이 리소스 부족으로 실패.
3. **BGRA 포맷 fix가 불완전**: YUV→BGRA 변환 버퍼 할당은 제거했지만, Vision의 ML inference 자체에 필요한 내부 버퍼 할당이 여전히 IOSurface pool과 경쟁.

### Evolution of Fixes

| Commit | Approach | Result |
|--------|----------|--------|
| `eb4061a7` | deep-copy pixel buffer | replaced by CGImage approach |
| `ed7ecb11` | CGImage for 3D only | 3D pool starvation solved |
| `bee039f6` | CGImage for ALL Vision | worked but GPU overhead at 10fps |
| `2ca0f96a` | pool buffer for 2D, CGImage for 3D | back to pool buffer for 2D |
| `ec33c724` | BGRA pixel format | reduced but didn't eliminate front camera failure |

## Solution

**Pool buffer를 Vision에 전달하지 않고, CPU 기반 CGImage 생성 후 전달.**

BGRA buffer에서 직접 CGImage를 생성(CPU memcpy)하면:
- IOSurface pool 의존성 완전 제거
- Vision은 일반 heap memory에서 ML buffer 할당 → TrueDepth 리소스와 무관
- CIContext GPU round-trip 불필요 → 이전 "CGImage for ALL" 방식의 성능 문제 해소

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/PostureCaptureService.swift` | `captureOutput` 내 2D detection을 CGImage 기반으로 전환, CGImage 생성 helper 추가 | pool buffer → CGImage로 전환 |
| `.claude/rules/performance-patterns.md` | AVCaptureSession Buffer Pool 규칙 업데이트 | 새 패턴 반영 |

## Implementation Steps

### Step 1: CGImage 생성 helper 추가

`PostureCaptureService`에 BGRA CVPixelBuffer → CGImage 변환 static method 추가:
- CVPixelBufferLockBaseAddress(.readOnly)
- Data(bytes:count:)로 pixel data 복사 (heap)
- CVPixelBufferUnlockBaseAddress
- CGImage(width:height:bitsPerComponent:bitsPerPixel:bytesPerRow:space:bitmapInfo:provider:decode:shouldInterpolate:intent:)

Verification: 컴파일 성공

### Step 2: captureOutput 내 2D detection 전환

`VNImageRequestHandler(cvPixelBuffer:)` → `VNImageRequestHandler(cgImage:)` 전환:
- helper로 CGImage 생성
- CGImage를 2D detection과 3D sampling에 공유
- 기존 CIContext.createCGImage 기반 3D CGImage 생성 제거 (동일 CGImage 재사용)
- cgImage creation throttle (cgImageCreationInterval) 제거 — 매 프레임 CGImage 생성

Verification: 전면/후면 카메라 모두 2D skeleton 표시

### Step 3: performance-patterns.md 업데이트

Buffer Pool 규칙에서 "2D detection: pool buffer 직접 사용 가능" 제거, CGImage 패턴으로 대체.

Verification: 규칙 내용 확인

## Test Strategy

- 전면 카메라: 2D skeleton overlay 표시 확인
- 전면 카메라: 3D score 업데이트 확인 (is3DActive = true)
- 후면 카메라: 기존 동작 유지 확인
- 빌드 검증: `scripts/build-ios.sh`
- 기존 테스트: PostureCaptureServiceTests, PostureAnalysisServiceTests

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| CPU memcpy overhead at 10fps | 720p BGRA = 3.6MB, ~0.4ms — 100ms budget 내 여유 |
| Heap allocation pressure (3.6MB/frame) | ARC 즉시 해제, transient allocation |
| YUV format fallback 시 CGImage 생성 불가 | BGRA 강제 유지, YUV fallback 시 기존 pool buffer 경로 보존 |
| Back camera 성능 저하 | pool buffer보다 ~0.4ms 느리지만 일관된 동작 보장 |
