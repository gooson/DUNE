---
tags: [posture, avfoundation, avcapturesession, threading, main-thread, ui-responsiveness]
category: performance
date: 2026-03-16
severity: important
related_files:
  - DUNE/Data/Services/PostureCaptureService.swift
related_solutions:
  - docs/solutions/performance/2026-03-16-cvpixelbuffer-pool-starvation-fix.md
---

# Solution: AVCaptureSession startRunning/stopRunning Off Main Thread

## Problem

Thread Performance Checker가 `AVCaptureSession.startRunning()`이 메인 스레드에서 호출되고 있다고 경고.

### Symptoms

- Xcode Thread Performance Checker 경고: `-[AVCaptureSession startRunning] should be called from background thread`
- 카메라 시작 시 UI가 일시적으로 멈출 수 있음 (startRunning은 blocking call)
- 백트레이스: `PostureCaptureService.startSession()` → `PostureAssessmentViewModel.setupCamera()` → `.task` (main thread)

### Root Cause

`PostureCaptureService.startSession()`이 `captureSession.startRunning()`을 동기적으로 호출. 호출자(`PostureAssessmentViewModel.setupCamera()`, `RealtimePostureViewModel.start()`)가 모두 `@MainActor` 컨텍스트이므로 메인 스레드에서 실행됨.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `PostureCaptureService.swift` | 전용 `sessionQueue` 추가 | 세션 start/stop을 메인 스레드에서 분리 |
| `PostureCaptureService.swift` | `startSession()` / `stopSession()`을 `sessionQueue.async`로 dispatch | blocking call을 백그라운드에서 실행 |

### Key Code

```swift
private let sessionQueue = DispatchQueue(label: "com.dune.posture.session")

func startSession() {
    sessionQueue.async { [captureSession] in
        guard !captureSession.isRunning else { return }
        captureSession.startRunning()
    }
}

func stopSession() {
    sessionQueue.async { [captureSession] in
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
    }
}
```

## Prevention

### 패턴: AVCaptureSession 메서드 호출 스레드

- `startRunning()` / `stopRunning()`은 **반드시 백그라운드 큐**에서 호출
- `beginConfiguration()` / `commitConfiguration()`도 동일 큐에서 호출 권장
- 전용 serial queue(`sessionQueue`)를 사용하여 start/stop 순서 보장
- `videoDataQueue`와 분리하여 프레임 처리와 세션 관리 간 상호 블로킹 방지

### Checklist Addition

- [ ] AVCaptureSession.startRunning/stopRunning이 메인 스레드에서 호출되지 않는지 확인

## Lessons Learned

1. `startRunning()`은 blocking call이므로 메인 스레드에서 호출하면 UI 응답성이 저하됨
2. Apple의 AVCam 샘플 코드는 전용 `sessionQueue`를 사용하는 것이 표준 패턴
3. 기존 `videoDataQueue`를 재사용하면 프레임 콜백과 세션 관리가 같은 큐에서 직렬화되어 상호 블로킹 위험
