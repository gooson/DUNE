---
topic: mlimage-buffer-pool-early-copy
date: 2026-03-16
status: draft
confidence: high
related_solutions:
  - docs/solutions/performance/2026-03-16-cvpixelbuffer-pool-starvation-fix.md
  - docs/solutions/performance/2026-03-16-avcapturesession-main-thread-fix.md
related_brainstorms: []
---

# Implementation Plan: Early Pixel Buffer Copy to Fix mlImage Buffer Creation Failure

## Context

실기기에서 자세교정 카메라 실행 시 `Could not create mlImage buffer of type kCVPixelFormatType_32BGRA` 에러가 지속적으로 발생. 기존 deep-copy 수정(2026-03-16)은 3D 파이프라인에만 적용되었으나, 2D VNImageRequestHandler도 pool-backed buffer를 직접 사용하여 Vision 내부 BGRA 변환 시 같은 풀 고갈 문제 발생.

### 근본 원인

`captureOutput` 콜백에서:
1. `CMSampleBufferGetImageBuffer(sampleBuffer)`로 pool-backed buffer 획득
2. `VNImageRequestHandler(cvPixelBuffer: pixelBuffer)` — Vision이 이 pool buffer를 참조
3. `handler.perform([bodyPoseRequest])` — Vision이 내부적으로 YUV→BGRA 변환 시도
4. 변환용 BGRA 버퍼 할당 실패 = pool 고갈 시그널
5. `averageLuminance(from: pixelBuffer)` — 여전히 pool buffer 보유
6. deep-copy for 3D — 이 시점에서야 독립 버퍼 생성

pool buffer가 콜백 전체 동안 잠기므로, 30fps 카메라 출력 중 다른 프레임의 pool buffer와 경합.

## Requirements

### Functional

- `captureOutput` 시작 직후 pool buffer를 deep-copy하고, 이후 모든 작업에 copy 사용
- 2D 감지, luminance, 3D 파이프라인 모두 동일한 copied buffer 사용
- copy 실패 시 해당 프레임 건너뛰기 (graceful degradation)

### Non-functional

- pool buffer 보유 시간: 현재 수십 ms → copy 시간(~1ms)으로 단축
- 10fps 처리율에서 초당 10회 copy — CPU 부하 미미 (memcpy < 1ms per 1280x720 frame)

## Approach

`captureOutput` 시작부에서 pool buffer를 즉시 deep-copy한 후, 모든 후속 작업(VNImageRequestHandler, averageLuminance, 3D 파이프라인)에 copied buffer 사용. 기존 late deep-copy 제거.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Early deep-copy (모든 연산에 copy 사용) | pool buffer 즉시 해제, 단순 | 10fps×copy 비용 | **채택** |
| Camera BGRA 출력 강제 | Vision 변환 불필요 | YUV 대비 2배 메모리, 2D pose에 불리 | 기각 |
| 2D detection만 copy 적용 | 변경 최소 | luminance도 pool 보유, 불완전 수정 | 기각 |
| VNImageRequestHandler에 options 전달 | API 수준 해결 | 해당 옵션 없음 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/PostureCaptureService.swift` | Modify | captureOutput에서 early copy 적용, late copy 제거 |

## Implementation Steps

### Step 1: captureOutput에서 early deep-copy 적용

- **Files**: `PostureCaptureService.swift`
- **Changes**:
  1. `CMSampleBufferGetImageBuffer` 직후 `Self.copyPixelBuffer(pixelBuffer)` 호출
  2. copy 실패 시 `return` (해당 프레임 건너뛰기)
  3. 이후 모든 코드에서 `pixelBuffer` 대신 `copiedBuffer` 사용:
     - `VNImageRequestHandler(cvPixelBuffer: copiedBuffer, ...)`
     - `CVPixelBufferGetWidth/Height(copiedBuffer)`
     - `Self.averageLuminance(from: copiedBuffer)`
  4. 기존 late deep-copy 블록(line 1152-1159) 제거 — 이미 copy된 buffer를 그대로 3D에 전달
- **Verification**: 빌드 성공, 시뮬레이터에서 카메라 시작/포즈 감지 동작

## Edge Cases

| Case | Handling |
|------|----------|
| copyPixelBuffer 실패 | return으로 프레임 건너뛰기 — 10fps 중 1프레임 유실은 무해 |
| YUV planar format | copyPixelBuffer가 이미 planar 지원 (plane별 memcpy) |
| BGRA interleaved format | copyPixelBuffer가 이미 interleaved 지원 |
| copy 후 원본 scope | sampleBuffer는 captureOutput 반환 시 자동 해제 — copy 후 즉시 반환 가능 |

## Testing Strategy

- Unit tests: `PostureCaptureServiceTests`의 기존 `copyPixelBuffer` 테스트 커버리지 유지
- Manual verification: 실기기에서 `mlImage buffer` 에러 미발생 확인
- Build: `scripts/build-ios.sh` 통과

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| copy 비용으로 10fps 미달 | Very Low | Low | 1280x720 YUV memcpy < 1ms, 100ms 예산 대비 1% |
| copy 실패로 프레임 유실 증가 | Very Low | Low | 메모리 부족 시에만 발생, 실사용 환경에서 극히 드뭄 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 `copyPixelBuffer` 유틸리티 재사용, 변경 범위가 단일 메서드, pool 고갈의 근본 원인(pool buffer 장기 보유)을 직접 해결
