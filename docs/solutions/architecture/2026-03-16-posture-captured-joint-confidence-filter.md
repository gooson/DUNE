---
tags: [posture, vision, 3d-pose, 2d-pose, confidence, overlay]
date: 2026-03-16
category: architecture
severity: important
related_files:
  - DUNE/Data/Services/PostureCaptureService.swift
  - DUNE/DUNETests/PostureAnalysisServiceTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-15-posture-assessment-vision-3d-pose.md
status: implemented
---

# Solution: Posture Captured Joint Confidence Filter

## Problem

자세 촬영 결과에서 일부 팔/다리 관절이 사진 바깥쪽이나 신체와 무관한 배경 위치로 튀는 경우가 있었다.

### Symptoms

- 저장된 자세 사진의 skeleton overlay에서 손목, 발목, 팔꿈치 같은 distal joint가 신체 밖으로 튄다.
- 실시간 미리보기에서는 상대적으로 덜 보이는데, 최종 결과 화면에서만 오탐 관절이 남는다.
- orientation fix 이후에도 특정 프레임에서만 overlay 품질이 흔들린다.

### Root Cause

문제는 `VNHumanBodyRecognizedPoint3D`가 **2D pose처럼 joint confidence를 직접 제공하지 않는다**는 점이다.
기존 구현은 `VNDetectHumanBodyPose3DRequest`의 3D joint와 `pointInImage()` projection만 저장했고,
최종 캡처 경로에서는 관절별 confidence를 검증하지 않았다.

즉, 3D projection 좌표가 존재한다는 이유만으로 관절을 저장하면,
Vision이 애매하게 추정한 distal joint가 그대로 overlay와 분석 파이프라인으로 흘러들어간다.

## Solution

최종 캡처 분석에서 3D request와 2D request를 **같은 이미지, 같은 orientation**으로 함께 수행한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/PostureCaptureService.swift` | 3D pose와 2D pose를 같은 handler에서 함께 실행 | 3D joint에 대응하는 2D confidence source 확보 |
| `DUNE/Data/Services/PostureCaptureService.swift` | 2D joint confidence → 3D joint 매핑 함수 추가 | `centerHead`, `centerShoulder`, `spine` 같은 derived joint도 confidence gate 적용 |
| `DUNE/Data/Services/PostureCaptureService.swift` | 저장용 joint filter에서 `nil` confidence를 reject로 변경 | 2D 미검출 joint가 필터를 우회하지 못하게 차단 |
| `DUNE/Data/Services/PostureCaptureService.swift` | `pointInImage()` 좌표를 finite + `[0, 1]` 범위로 제한 | 비정상 projection 값이 overlay로 저장되지 않게 방어 |
| `DUNE/DUNETests/PostureAnalysisServiceTests.swift` | low-confidence, missing-confidence, non-finite 회귀 테스트 추가 | 리뷰 finding과 재발 경로를 자동 검증 |

### Key Code

```swift
let confidenceBy2DJointName = Self.captureConfidenceBy2DJointName(
    from: confidenceRequest.results?.first
)

guard Self.shouldKeepCapturedJoint(
    confidence: Self.capturedJointConfidence(
        for: name,
        confidenceBy2DJointName: confidenceBy2DJointName
    ),
    x: x,
    y: y,
    z: z
) else {
    continue
}
```

핵심 정책은 다음과 같다.

1. `VNDetectHumanBodyPose3DRequest`로 3D joint와 `pointInImage()` 좌표를 얻는다.
2. 같은 `VNImageRequestHandler`에서 `VNDetectHumanBodyPoseRequest`도 함께 실행한다.
3. 2D observation의 joint confidence를 3D joint에 매핑한다.
   - `centerHead`, `topHead` → `.nose`
   - `centerShoulder` → `.neck`
   - `spine` → `min(.neck, .root)`
   - 사지/엉덩이/무릎/발목/어깨/팔꿈치/손목/`root` → 동일 joint 직접 매핑
4. 최종 저장용 joint는 `confidence >= 0.5`인 경우만 유지하고, 매핑된 2D confidence가 없으면 해당 3D joint를 버린다.
5. 실시간 가이던스 overlay는 UX 반응성을 위해 기존처럼 더 느슨한 `0.3` threshold를 유지한다.
6. `pointInImage()` 좌표는 finite + `[0, 1]` 범위일 때만 저장한다.

이렇게 하면 미리보기는 충분히 민감하게 유지하면서도,
저장/분석용 결과에는 약한 outlier joint가 섞이지 않는다.

## Prevention

### Checklist Addition

- [ ] Vision 3D pose 결과를 저장할 때 per-joint confidence source가 실제로 존재하는지 확인했는가?
- [ ] derived 3D joint(`centerHead`, `centerShoulder`, `spine`)에 대응하는 confidence 매핑이 정의되어 있는가?
- [ ] mapped confidence가 없을 때 fallback pass-through가 아니라 reject로 처리되는가?
- [ ] overlay projection 값이 finite + normalized range인지 검증했는가?

### Rule Addition

`docs/corrections-active.md`에 posture/Vision 전용 correction을 추가해,
3D joint confidence가 필요할 때는 2D pose를 함께 실행하고 missing mapped confidence를 reject하도록 남긴다.

## Lessons Learned

- Vision 3D pose는 joint 위치는 주지만, UI 품질에 필요한 confidence contract까지 다 주지는 않는다.
- “값이 없으면 일단 통과” 같은 fallback은 pose/overlay 계열에서 버그를 다시 열기 쉽다.
- 실시간 가이던스 threshold와 저장용 threshold를 분리해야 UX와 결과 품질을 동시에 맞출 수 있다.
