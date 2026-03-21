---
tags: [camera, mac, posture, rotation, preview, RotationCoordinator, KVO]
date: 2026-03-21
category: plan
status: draft
---

# Plan: Mac 카메라 프리뷰 90° 회전 문제 수정

## Problem

맥앱(Designed for iPad on Mac)에서 자세 평가 카메라 프리뷰가 90° 회전되어 표시됨. iOS에서는 정상 동작.

### Root Cause

`CameraPreviewUIView.updatePreview()`가 `videoRotationAngleForHorizonLevelPreview`를 한 번만 읽고 설정함. iOS에서는 기기 회전으로 `updateUIView`가 재호출되지만, Mac에서는:

1. `UIDevice.current.orientation`이 항상 `.unknown` → 재호출 트리거 없음
2. `makeUIView` 시점에 `previewLayer.connection`이 아직 nil일 수 있음 → early return으로 rotation 미적용
3. RotationCoordinator가 previewLayer 프레임 안정화 후 정확한 각도를 제공하더라도 읽는 시점이 지남

### Fix Strategy

Apple의 AVCam 샘플 패턴대로 RotationCoordinator의 `videoRotationAngleForHorizonLevelPreview`를 KVO 관찰하여 변경 시 preview connection에 자동 반영.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Presentation/Posture/PostureCaptureView.swift` | `CameraPreviewUIView`에 KVO observation 추가 | Low — 기존 동작 보존, KVO 콜백 추가 |

## Implementation Steps

### Step 1: CameraPreviewUIView에 KVO observation 추가

1. `rotationObservation: NSKeyValueObservation?` 프로퍼티 추가
2. RotationCoordinator 생성 직후 `observe(\.videoRotationAngleForHorizonLevelPreview)` KVO 등록
3. KVO 콜백에서 `previewLayer.connection?.videoRotationAngle` 업데이트 + `onPreviewRotationAngleChange` 콜백 호출
4. `updatePreview()`에서 기존 1회 읽기 로직은 제거하지 않음 (초기값 설정 역할 유지)
5. RotationCoordinator 교체 시 기존 observation 해제

### Step 2: Vision 파이프라인 확인 (분석만)

Mac에서 `captureOutput` 핸들러의 Vision orientation도 올바른지 확인. `livePreviewRotationAngle`이 KVO 콜백으로 업데이트되므로 자동으로 해결됨.

## Test Strategy

- Mac에서 자세 평가 카메라 열고 프리뷰가 정상 방향인지 확인 (수동 — 시뮬레이터 카메라 제한)
- iOS에서 기존 동작 깨지지 않는지 확인
- 빌드 통과 확인

## Risks / Edge Cases

- KVO 콜백이 background thread에서 호출될 수 있음 → `DispatchQueue.main.async` 래핑 필요
- RotationCoordinator 해제 시 observation도 반드시 해제 (retain cycle 방지)
- `isVideoRotationAngleSupported` 체크 필수 (지원하지 않는 각도 방어)
