---
tags: [posture, realtime, vision, fallback, contract]
category: general
date: 2026-03-22
severity: important
related_files:
  - DUNE/Data/Services/PostureCaptureService.swift
  - DUNE/Data/Services/RealtimePoseTracker.swift
  - DUNETests/PostureCaptureServiceTests.swift
  - DUNETests/RealtimePoseTrackerTests.swift
related_solutions: []
---

# Solution: Realtime 3D Fallback Contract 분리

## Problem

최신 main에서 자세 캡처 파이프라인은 3D 감지가 실패하면 2D joint fallback을 반환하도록 바뀌었다. 그런데 realtime tracker는 `detectPoseFromVideoFrame`가 성공적으로 값을 반환하기만 하면 그것을 "3D 성공"으로 간주하고 있었다.

### Symptoms

- 전면 카메라에서 3D가 실제로 실패해도 realtime UI가 `3D` 배지를 표시함
- fallback 2D 결과가 더 정확한 3D 점수처럼 최근 score를 덮어씀
- 카메라 에러가 발생하는 기기에서 realtime 점수 의미가 불안정해짐

### Root Cause

`PostureCaptureResult`가 "이 결과가 진짜 3D인지, 2D fallback인지"를 표현하지 못했다. 호출부는 `heightEstimation == .reference` 같은 간접 신호나 성공/실패 여부만 보고 의미를 추론해야 했고, 그 결과 캡처 서비스와 realtime tracker 사이 계약이 깨졌다.

## Solution

결과 객체에 pose provenance를 명시적으로 추가하고, realtime tracker가 그 값으로만 3D 활성화 여부와 precise score override를 결정하도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/PostureCaptureService.swift` | `PostureCapturePoseSource`와 `poseSource` 추가 | 3D vs 2D fallback을 명시적으로 전달하기 위해 |
| `DUNE/Data/Services/PostureCaptureService.swift` | averaging 결과의 pose source를 보수적으로 계산 | 섞인 샘플을 잘못된 true 3D로 승격하지 않기 위해 |
| `DUNE/Data/Services/RealtimePoseTracker.swift` | true 3D일 때만 precise score와 `is3DActive` 갱신 | fallback 결과가 3D 성공처럼 보이지 않도록 하기 위해 |
| `DUNETests/PostureCaptureServiceTests.swift` | provenance/averaging 테스트 추가 | 계약 회귀를 막기 위해 |
| `DUNETests/RealtimePoseTrackerTests.swift` | precise score gating 테스트 추가 | realtime override 조건을 고정하기 위해 |

### Key Code

```swift
enum PostureCapturePoseSource: String, Sendable, Hashable {
    case threeD
    case twoDFallback
}

guard result.hasTrue3DPose else { return nil }
```

## Prevention

### Checklist Addition

- [ ] 캡처 결과가 여러 모드를 fallback할 수 있으면 provenance를 enum/flag로 명시한다
- [ ] realtime/UI 상태는 "함수 성공 여부"가 아니라 결과 의미를 보고 갱신한다
- [ ] 3D 여부를 `heightEstimation`, `z == 0`, joint 개수 같은 간접 신호로 추론하지 않는다

### Rule Addition (if applicable)

비슷한 multimodal/fallback 계약이 늘어나면 서비스 경계에서 provenance를 필수 필드로 갖는 규칙을 추가할 수 있다.

## Lessons Learned

fallback을 추가한 시점부터 반환 타입의 의미도 함께 확장해야 한다. "에러를 덜 던진다"는 변화는 호출부 입장에서는 성공 의미의 확장이고, 이 계약을 명시하지 않으면 UI와 점수 파이프라인이 조용히 오작동한다.
