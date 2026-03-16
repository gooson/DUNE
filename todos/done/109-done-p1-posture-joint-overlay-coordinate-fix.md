---
source: review/swift-ui-expert
priority: p1
status: done
created: 2026-03-15
updated: 2026-03-15
---

# JointOverlayView 좌표계 수정

## 문제

Vision 3D Pose는 관절 좌표를 **미터 단위** (root joint 기준 상대 좌표)로 반환하는데,
현재 `JointOverlayView`는 `x + 0.5`, `1.0 - (y + 0.5)` 로 정규화된 [0,1] 좌표로 가정하고 있음.

사람 크기/거리에 따라 관절 오버레이가 잘못된 위치에 렌더링됨.

## 해결 방향

- 캡처 시점에 `VNHumanBodyPose3DObservation.pointInImage(_:)` 로 2D 이미지 좌표 추출
- 또는 카메라 intrinsics 기반 3D→2D 투영
- `JointPosition3D` 모델에 2D 이미지 좌표 필드 추가 고려

## 영향 파일

- `DUNE/Presentation/Posture/JointOverlayView.swift`
- `DUNE/Data/Services/PostureCaptureService.swift`
- `DUNE/Domain/Models/PostureAssessment.swift`
