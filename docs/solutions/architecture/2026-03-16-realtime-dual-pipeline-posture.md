---
tags: [posture, realtime, vision, dual-pipeline, avfoundation]
date: 2026-03-16
category: solution
status: implemented
---

# Realtime Dual Pipeline Posture Analysis

## Problem

정지 사진 기반 자세 분석만 존재 → 실시간 피드백 불가.
매 프레임 3D 감지는 ~50-100ms/frame으로 실시간 불가 (A17 Pro 기준).

## Solution

2D 연속 + 3D 주기적 감지를 병렬 수행하는 **듀얼 파이프라인** 아키텍처.

### 파이프라인 구조

```
Camera (AVCaptureSession)
  │
  ├─ 2D: VNDetectHumanBodyPoseRequest → 매 프레임 (10fps throttle)
  │     → PostureAnalysisService.estimateAnglesFrom2D()
  │     → 스켈레톤 + 각도 오버레이
  │
  └─ 3D: VNDetectHumanBodyPose3DRequest → 주기적 (~4fps)
        → PostureAnalysisService.analyzeFrontView/SideView()
        → 정밀 점수 업데이트
```

### 핵심 설계 결정

1. **CMSampleBuffer 전달**: CVPixelBuffer 직접 전달은 AVFoundation pool recycling으로 데이터 손상 위험. CMSampleBuffer를 Task 클로저에 캡처하면 Swift ARC가 pixel buffer를 보호.

2. **CIContext 캐싱**: `CIContext()`는 GPU 리소스를 할당하는 heavyweight 객체. 4fps 호출 시 초당 4회 생성 → `static let` 캐싱 필수. CIContext는 thread-safe.

3. **UI 업데이트 스로틀링**: 2D 파이프라인이 10fps로 결과를 생산하지만 MainActor 업데이트는 10fps로 제한. AngleOverlay Canvas는 `symbols:` API를 사용하여 SwiftUI가 텍스트 resolve를 캐싱.

4. **3D 점수 override**: ScoreRingBuffer에 `replaceLast()` 추가. 같은 프레임 구간에서 2D rough score 이후 3D precise score가 도착하면 최근 항목을 교체 (double-write 방지).

5. **Domain 순수성**: `RealtimeAngle`에 `displayPosition: CGPoint` 대신 `jointName: String`을 저장. Presentation layer에서 skeleton keypoints를 참조하여 화면 좌표를 계산.

6. **Task 취소**: `pending3DTask` 참조를 저장하고 `stop()` 시 cancel + `isStopped` guard. 화면 dismiss 후 3D Vision inference가 계속 실행되는 것을 방지.

### 파일 구조

| Layer | File | Role |
|-------|------|------|
| Domain | `RealtimePoseState.swift` | RealtimeAngle, RealtimePoseState, ScoreRingBuffer |
| Domain | `PostureAnalysisService.swift` | estimateAnglesFrom2D() 추가 |
| Data | `PostureCaptureService.swift` | detectPoseFromVideoFrame(), onRealtimeFrame 콜백 |
| Data | `RealtimePoseTracker.swift` | 듀얼 파이프라인 관리, 스코어 스무딩, 타임아웃 |
| Presentation | `RealtimePostureViewModel.swift` | @Observable @MainActor, 카메라 전환 |
| Presentation | `RealtimePostureView.swift` | 카메라 + 스켈레톤 + 각도 + 점수 오버레이 |
| Presentation | `AngleOverlay.swift` | Canvas symbols API, 관절 위치에 각도 표시 |
| Presentation | `RealtimeScoreBadge.swift` | 실시간 점수 배지, 색상 코딩 |

## Prevention

### CVPixelBuffer 수명 관리
- AVFoundation delegate에서 async Task로 전달 시 반드시 CMSampleBuffer 단위로 캡처
- CVPixelBuffer 직접 전달 금지 (pool recycling)

### CIContext 재사용
- `CIContext()` 생성은 `private static let` 또는 stored property
- 반복 호출되는 경로에서 매번 생성 금지

### 비정형 Task 관리
- `@unchecked Sendable` 클래스에서 spawned Task는 참조를 저장하고 cleanup 시 cancel
- `guard !Task.isCancelled` 패턴을 async 작업 전후에 적용
