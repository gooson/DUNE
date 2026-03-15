---
tags: [posture, camera, overlay, orientation, rotation-coordinator, image-metadata]
category: architecture
date: 2026-03-16
severity: critical
related_files:
  - DUNE/Data/Services/PostureCaptureService.swift
  - DUNE/Presentation/Posture/PostureCaptureView.swift
  - DUNE/Presentation/Posture/Components/BodyGuideOverlay.swift
  - DUNE/Presentation/Posture/Components/ZoomablePostureImageView.swift
  - DUNE/Presentation/Posture/PostureResultView.swift
  - DUNE/Presentation/Posture/PostureDetailView.swift
  - DUNE/Presentation/Posture/PostureComparisonView.swift
  - DUNE/DUNETests/PostureAnalysisServiceTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-16-posture-captured-joint-confidence-filter.md
  - docs/solutions/general/2026-03-16-posture-realtime-guidance.md
---

# Solution: Posture Orientation Coordinate Contract

## Problem

Posture skeleton rendering was still wrong even after filtering bad 3D joints. The live preview and the captured-result screen were each using different orientation and projection assumptions.

### Symptoms

- Live camera preview skeleton drifted when the device rotated or when the preview used aspect-fill crop.
- Landscape captures could look correct at capture time but render with a wrong fallback rotation afterward.
- Front-camera preview and post-capture overlay could disagree even when the same body pose was detected.

### Root Cause

The pipeline had three separate coordinate systems with no shared contract:

1. `AVCaptureVideoDataOutput` used a fixed `videoRotationAngle = 90`.
2. Live Vision overlay converted normalized points directly into the full screen rect, ignoring preview crop and relying on a hard-coded device-orientation mapping.
3. Result display still treated any landscape posture image as a legacy broken photo and rotated it blindly.

So even after bad 3D joints were filtered out, the preview path and display path could still render correct joints in the wrong place.

## Solution

Unify preview/capture/display orientation handling around explicit rotation and image metadata.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/PostureCaptureService.swift` | Reset video-data output rotation to `0` and pass explicit Vision orientation metadata per frame | avoid device-specific implicit buffer rotations |
| `DUNE/Data/Services/PostureCaptureService.swift` | Added `AVCaptureDevice.RotationCoordinator` for photo capture rotation | use Apple-provided horizon-level capture angle instead of fixed `90°` |
| `DUNE/Data/Services/PostureCaptureService.swift` | Accept preview rotation angle updates from the preview layer and reuse them for live Vision orientation | keep live skeleton and preview layer on the same rotation source |
| `DUNE/Presentation/Posture/Components/BodyGuideOverlay.swift` | Project live skeleton with aspect-fill math based on oriented image size | align SwiftUI overlay with preview crop |
| `DUNE/Presentation/Posture/PostureCaptureView.swift` | Report preview-layer rotation angle back to the capture service | close the last preview/Vision mismatch on newer hardware |
| `DUNE/Domain/Models/PostureImageMetadata.swift` | Added explicit marker for newly normalized posture JPEGs | distinguish new upright captures from legacy broken photos |
| `DUNE/Presentation/Posture/Components/ZoomablePostureImageView.swift` | Run legacy 90° correction only for unmarked posture images | stop mis-rotating new landscape captures |
| `DUNE/Presentation/Posture/PostureResultView.swift` | Reused shared display-context helper | keep current result screen consistent |
| `DUNE/Presentation/Posture/PostureDetailView.swift` | Reused shared display-context helper | keep saved-record detail screen consistent |
| `DUNE/Presentation/Posture/PostureComparisonView.swift` | Reused shared display-context helper | keep comparison screen consistent |
| `DUNE/DUNETests/PostureAnalysisServiceTests.swift` | Added marker-vs-legacy display regression coverage | lock the image-display contract in tests |

### Key Code

```swift
let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview ?? 0
connection.videoRotationAngle = angle
onPreviewRotationAngleChange?(angle)
```

```swift
let orientation: CGImagePropertyOrientation
if let previewRotationAngle = livePreviewRotationAngle {
    orientation = Self.liveVisionOrientation(
        forPreviewRotationAngle: previewRotationAngle
    )
} else {
    orientation = Self.liveVisionOrientation(for: liveDeviceOrientation)
}
```

```swift
let needsLegacyCorrection =
    !imageData.hasNormalizedPostureMarker &&
    rawImage.needsLegacyPostureOrientationCorrection
```

## Prevention

### Checklist Addition

- [ ] Camera preview rotation source와 live Vision orientation source가 같은 계약을 공유하는가?
- [ ] `resizeAspectFill` preview 위에 normalized point를 직접 screen rect에 투영하지 않았는가?
- [ ] 새 posture image pipeline이 legacy fallback과 구분되는 explicit marker를 남기는가?
- [ ] landscape posture image를 자동 회전하기 전에 “이게 정말 legacy broken image인가?”를 확인하는가?

### Rule Addition (if applicable)

`docs/corrections-active.md`에 posture preview/capture rotation contract와 posture image marker 규칙을 추가한다.

## Lessons Learned

- 관절 confidence를 올바르게 걸러도, preview/capture/display가 서로 다른 좌표계를 쓰면 skeleton은 여전히 틀어진다.
- posture camera 문제는 “좌우 반전” 한 종류로 뭉개면 안 되고, rotation, crop, mirroring, legacy image fallback을 각각 분리해서 다뤄야 한다.
- 새 capture pipeline이 과거 workaround와 공존해야 한다면, heuristic보다 explicit marker가 훨씬 안전하다.
