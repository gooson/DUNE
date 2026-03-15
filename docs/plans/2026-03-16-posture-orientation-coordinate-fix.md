---
topic: posture orientation coordinate fix
date: 2026-03-16
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-16-posture-captured-joint-confidence-filter.md
related_brainstorms:
  - docs/brainstorms/2026-03-16-posture-capture-guideline-improvement.md
---

# Implementation Plan: Posture Orientation Coordinate Fix

## Context

Posture capture still renders broken skeletons in two places:

1. Live camera preview: the SwiftUI overlay projects Vision points directly into the screen rect while the preview layer uses `resizeAspectFill`, mirroring, and device rotation independently.
2. Post-capture result: current display code still assumes any landscape posture image is a legacy bad photo and forcibly rotates it, which breaks new landscape captures.

The previously shipped 2D-confidence gate fixed one class of 3D outliers, but it did not repair the shared coordinate-space contract between camera preview, Vision, and the saved image display.

## Requirements

### Functional

- Live preview skeleton must stay aligned with the camera preview in portrait and landscape.
- Captured-result skeleton must align with newly captured images regardless of device rotation.
- Legacy malformed posture images should keep their fallback correction path.

### Non-functional

- Use Apple rotation APIs that account for device/camera differences instead of hard-coded angles.
- Avoid introducing a second ad-hoc transform path for live vs captured overlays.
- Add regression coverage for the new orientation/display contracts.

## Approach

Adopt `AVCaptureDevice.RotationCoordinator` as the single source of truth for preview/capture rotation, and stop projecting live skeletons with a naive full-screen transform.

- Preview path:
  - Feed the preview layer the coordinator-provided horizon-level rotation.
  - Draw the live skeleton inside the preview-backed UIView using `AVCaptureVideoPreviewLayer` point conversion so `resizeAspectFill`, crop, and mirroring are handled by AVFoundation.
  - Keep SwiftUI `BodyGuideOverlay` focused on guide chrome, not raw skeleton projection.
- Capture path:
  - Apply the coordinator-provided capture rotation to photo/video connections before capture.
  - Continue using the photo EXIF orientation for Vision 3D analysis.
- Result display path:
  - Tag newly re-encoded posture JPEGs with an explicit metadata marker.
  - Only run the old landscape-rotation fallback for untagged legacy images.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Keep hard-coded `videoRotationAngle = 90` and patch landscape cases | Small diff | Still device-specific, still wrong on newer hardware, still splits preview/capture contracts | Rejected |
| Compute crop + rotation + mirroring manually in SwiftUI overlay | Avoids UIKit overlay work | Reimplements AVFoundation math, higher regression risk | Rejected |
| Use `AVCaptureDevice.RotationCoordinator` + preview-layer point conversion | Uses Apple-supported rotation source and preview conversion | Requires touching service + preview view + overlay plumbing | Chosen |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/PostureCaptureService.swift` | Refactor | Replace fixed rotation handling with coordinator-backed preview/capture rotation and shared live overlay metadata |
| `DUNE/Presentation/Posture/PostureCaptureView.swift` | Refactor | Pass live skeleton data into preview UIView and wire preview rotation updates |
| `DUNE/Presentation/Posture/Components/BodyGuideOverlay.swift` | Refactor | Remove naive skeleton projection from the SwiftUI overlay |
| `DUNE/Presentation/Posture/Components/ZoomablePostureImageView.swift` | Refactor | Distinguish legacy broken posture images from new upright captures |
| `DUNE/Presentation/Posture/PostureResultView.swift` | Refactor | Use the new display-context helper for current captures |
| `DUNE/Presentation/Posture/PostureDetailView.swift` | Refactor | Use the new display-context helper for persisted captures |
| `DUNE/Presentation/Posture/PostureComparisonView.swift` | Refactor | Use the new display-context helper for comparisons |
| `DUNE/Domain/Models/PostureImageMetadata.swift` | New file | Shared metadata marker for posture JPEG orientation/display handling |
| `DUNE/DUNETests/PostureAnalysisServiceTests.swift` | Test | Add orientation/display regression coverage |

## Implementation Steps

### Step 1: Unify live preview rotation and skeleton rendering

- **Files**: `PostureCaptureService.swift`, `PostureCaptureView.swift`, `BodyGuideOverlay.swift`
- **Changes**:
  - Introduce a coordinator-backed rotation source for preview/capture.
  - Route live keypoints into the preview UIView and render them with preview-layer point conversion.
  - Stop using the SwiftUI overlay for direct skeleton coordinate projection.
- **Verification**:
  - Build succeeds.
  - Live skeleton render path no longer depends on `visionToScreen`.

### Step 2: Remove false-positive legacy correction for new captures

- **Files**: `PostureCaptureService.swift`, `PostureImageMetadata.swift`, `ZoomablePostureImageView.swift`, `PostureResultView.swift`, `PostureDetailView.swift`, `PostureComparisonView.swift`
- **Changes**:
  - Mark newly compressed posture JPEGs.
  - Switch image display to explicit metadata detection instead of `size.width > size.height`.
- **Verification**:
  - New tagged images skip legacy rotation fallback.
  - Untagged legacy landscape images still use the fallback.

### Step 3: Add regression coverage and rerun posture validation

- **Files**: `PostureAnalysisServiceTests.swift`
- **Changes**:
  - Add tests for the new display-context decision and orientation marker detection.
  - Keep existing joint-confidence regressions intact.
- **Verification**:
  - Targeted posture test suite passes.
  - iOS build succeeds.

## Edge Cases

| Case | Handling |
|------|----------|
| Front camera mirroring differs from back camera | Preview skeleton uses preview-layer conversion so mirroring stays in one place |
| Device rotates after the session starts | Rotation coordinator updates preview/capture angles without hard-coded assumptions |
| New landscape capture should stay landscape | Tagged JPEG skips legacy portrait fallback |
| Old broken portrait photo stored as landscape pixels | Untagged image still uses legacy correction helper |
| `RotationCoordinator` preview layer missing from hierarchy briefly | Fallback to previous/default rotation until the layer is attached |

## Testing Strategy

- Unit tests: marker detection + legacy correction decision tests in `PostureAnalysisServiceTests.swift`
- Integration tests: targeted posture service/view model tests via `xcodebuild test -only-testing DUNETests/PostureAnalysisServiceTests`
- Manual verification:
  - Front camera portrait live preview alignment
  - Front camera landscape live preview alignment
  - Post-capture result alignment in portrait and landscape
  - Legacy saved posture photo still displays correctly

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Rotation coordinator updates differ between simulator and device | Medium | High | Keep targeted manual verification on device in final report |
| Preview UIView overlay introduces redraw issues | Medium | Medium | Use lightweight shape layers and avoid redundant full-view recomposition |
| Metadata marker not preserved through future recompression paths | Low | Medium | Centralize marker constant and encode/decode helpers in one shared file |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: The failure mode is well isolated, and Apple SDK headers explicitly recommend coordinator-driven rotation over fixed angles. The main uncertainty is real-device behavior across front-camera combinations, so manual verification remains necessary after automated checks.
