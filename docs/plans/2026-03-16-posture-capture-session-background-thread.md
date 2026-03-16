---
topic: posture-capture-session-background-thread
date: 2026-03-16
status: draft
confidence: high
related_solutions:
  - docs/solutions/performance/2026-03-16-cvpixelbuffer-pool-starvation-fix.md
related_brainstorms: []
---

# Implementation Plan: AVCaptureSession startRunning/stopRunning Background Thread

## Context

Thread Performance Checker가 `AVCaptureSession.startRunning()`이 메인 스레드에서 호출되고 있다고 경고. Apple 문서에 따르면 `startRunning()`은 blocking call이므로 메인 스레드에서 호출하면 UI가 멈출 수 있음.

현재 `PostureCaptureService.startSession()`은 동기적으로 `captureSession.startRunning()`을 호출하며, 이를 호출하는 `PostureAssessmentViewModel.setupCamera()`와 `RealtimePostureViewModel.start()`는 모두 `@MainActor` 컨텍스트에서 실행됨.

## Requirements

### Functional

- `startRunning()`과 `stopRunning()`이 메인 스레드가 아닌 전용 백그라운드 큐에서 실행되어야 함
- 기존 동작(카메라 시작/정지)이 동일하게 유지되어야 함

### Non-functional

- UI 응답성 개선 (메인 스레드 블로킹 제거)
- Thread Performance Checker 경고 해소

## Approach

전용 `sessionQueue` (serial DispatchQueue)를 추가하고, `startRunning()`/`stopRunning()` 호출을 이 큐로 dispatch. Apple의 AVCaptureSession 가이드에서 권장하는 패턴.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 전용 sessionQueue | Apple 권장 패턴, 간단 | 큐 하나 추가 | **채택** |
| 기존 videoDataQueue 재사용 | 큐 추가 불필요 | session 관리와 frame 처리가 같은 큐에서 실행되면 상호 블로킹 가능 | 기각 |
| DispatchQueue.global() 사용 | 큐 추가 불필요 | concurrent 큐에서 start/stop 경합 가능 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/PostureCaptureService.swift` | Modify | sessionQueue 추가, startSession/stopSession을 async dispatch로 변경 |

## Implementation Steps

### Step 1: sessionQueue 추가 및 start/stop 변경

- **Files**: `PostureCaptureService.swift`
- **Changes**:
  1. `private let sessionQueue = DispatchQueue(label: "com.dune.posture.session")` 추가
  2. `startSession()`에서 `sessionQueue.async { [captureSession] in ... }` 패턴 적용
  3. `stopSession()`에도 동일 패턴 적용
- **Verification**: `scripts/build-ios.sh` 빌드 성공

## Edge Cases

| Case | Handling |
|------|----------|
| start/stop 빠른 연속 호출 | serial queue이므로 순서 보장됨 |
| updateLiveConfiguration에서 wasRunning → startSession | startSession이 async이지만 setupCamera는 이미 synchronous로 captureSession을 구성하므로 문제 없음 |
| stopSession 후 즉시 리소스 해제 | stopRunning이 완료되기 전에 captureSession이 deallocate될 수 있으나, capture list `[captureSession]`이 강참조를 유지 |

## Testing Strategy

- Unit tests: 이 변경은 threading 변경만이므로 기존 PostureCaptureServiceTests가 커버
- Manual verification: 시뮬레이터에서 카메라 시작 시 Thread Performance Checker 경고 미발생 확인
- Build: `scripts/build-ios.sh` 통과

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| async dispatch로 인한 타이밍 변경 | Low | Low | serial queue로 순서 보장, 호출자는 이미 startRunning 완료를 기다리지 않음 |
| 시뮬레이터 한정 검증 | Medium | Low | 실기기 테스트는 사용자가 수행 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: Apple 공식 권장 패턴이며, 변경 범위가 단일 파일의 3개 메서드로 최소화됨. 호출자 코드 변경 불필요.
