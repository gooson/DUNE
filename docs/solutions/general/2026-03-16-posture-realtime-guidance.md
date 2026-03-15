---
tags: [posture, vision, 2d-pose, guidance, camera, auto-capture, tts]
date: 2026-03-16
category: solution
status: implemented
---

# Real-time 2D Pose Guidance for Posture Capture

## Problem

기존 자세 촬영 가이드는 정적 점선 실루엣으로만 안내하여:
- 사용자가 정확한 위치를 찾기 어려움 (거리감 없음)
- 머리 모양을 실루엣에 맞추려다 촬영 실패
- 조명/안정성 피드백 없음 → 품질 낮은 촬영 반복

## Solution

### Architecture

```
PostureCaptureService (Data)
├── AVCaptureVideoDataOutput → 실시간 프레임 처리 (10fps 스로틀)
├── VNDetectHumanBodyPoseRequest (2D) → 실시간 가이던스
├── PostureGuidanceAnalyzer → GuidanceState 생성
└── Callbacks: onGuidanceUpdate, onSkeletonUpdate

PostureGuidanceAnalyzer (Data)
├── checkFullBodyVisible: nose + ankle 감지
├── checkDistance: head-ankle ratio → DistanceStatus
├── checkStability: nose 위치 분산 (5프레임)
├── lightingStatus: Y-plane 휘도 샘플링
├── checkOrientation: 양쪽 어깨 감지
└── checkArmsRelaxed: 손목이 엉덩이 아래

GuidanceState (Domain)
├── isReady: 6개 조건 모두 충족 시 true
├── primaryHint: 가장 중요한 미충족 조건
└── satisfiedCount: 충족된 조건 수 (4개 체크리스트 기준)

PostureAssessmentViewModel (Presentation)
├── handleGuidanceUpdate: auto-capture 로직 (2초 유지 → countdown)
├── TTS: back camera 시 AVSpeechSynthesizer로 카운트다운
└── Camera switching: front/back 전환
```

### Key Design Decisions

1. **2D vs 3D Pose**: 실시간 가이던스에 2D (`VNDetectHumanBodyPoseRequest`), 최종 분석에 3D (`VNDetectHumanBodyPose3DRequest`). 2D가 빠르고 가이던스 용도에 충분함.

2. **10fps 스로틀**: `CFAbsoluteTime` 기반으로 프레임 간격 0.1초 제한. 배터리/CPU 절약과 UX 반응성의 균형.

3. **Zone-based overlay**: 실루엣 대신 RoundedRectangle zone + 실시간 skeleton Canvas 오버레이. 사용자가 "zone 안에 들어가면 됨" — 직관적.

4. **Auto-capture**: GuidanceState.isReady가 2초 연속 유지 → 자동 countdown 시작. 카운트다운 중 pose 소실 시 자동 취소.

5. **Back camera TTS**: 후면 카메라 시 화면을 볼 수 없으므로 AVSpeechSynthesizer로 카운트다운 음성 안내.

6. **VNDetectHumanBodyPoseRequest reuse**: 매 프레임마다 새 request 생성하지 않고 stored property로 재사용 (P1 성능 fix).

### Distance Detection

Vision normalized 좌표 (origin bottom-left)에서 nose-ankle 거리 비율로 판단:
- `< 0.4` → tooFar
- `< 0.55` → slightlyFar
- `≤ 0.85` → optimal
- `> 0.85` → tooClose

### Luminance Detection

CVPixelBuffer의 Y plane에서 16픽셀마다 샘플링하여 평균 휘도 계산:
- `< 0.15` → tooLow (촬영 부적합)
- `< 0.25` → adequate
- `≥ 0.25` → good

### Skeleton Rendering

Vision 2D keypoints를 Canvas로 렌더링:
- 13개 관절 (nose, shoulders, elbows, wrists, hips, knees, ankles)
- 연결선: 몸통, 팔, 다리 (confidence > 0.3인 포인트만)
- 좌표 변환: Vision normalized (bottom-left origin) → screen (top-left origin)
- Front camera: 좌우 미러링 적용

## Files

| File | Layer | Role |
|------|-------|------|
| `Domain/Models/PostureGuidance.swift` | Domain | GuidanceState, DistanceStatus, GuidanceHint 등 모델 |
| `Data/Services/PostureGuidanceAnalyzer.swift` | Data | 2D pose → GuidanceState 변환 |
| `Data/Services/PostureCaptureService.swift` | Data | 카메라 세션 + 실시간 프레임 처리 |
| `Presentation/Posture/PostureAssessmentViewModel.swift` | Presentation | auto-capture, TTS, 상태 관리 |
| `Presentation/Posture/PostureCaptureView.swift` | Presentation | 촬영 화면 전체 |
| `Presentation/Posture/Components/BodyGuideOverlay.swift` | Presentation | zone + skeleton overlay |
| `Presentation/Posture/Components/DistanceIndicatorView.swift` | Presentation | 거리 표시 바 |
| `Presentation/Posture/Components/GuidanceChecklistView.swift` | Presentation | 4개 조건 체크리스트 |

## Prevention

- **VNRequest 재사용**: Vision request는 stored property로 선언하여 per-frame allocation 방지
- **프레임 스로틀링**: 실시간 비디오 처리 시 반드시 fps 제한 적용 (10fps 이하 권장)
- **Domain 분리**: GuidanceHint.displayMessage처럼 사용자 대면 텍스트는 domain 모델의 computed property로 배치하여 View에서 switch 중복 방지
- **TTS 통합**: speak() 단일 메서드로 통합, 카운트다운과 일반 안내를 분리하지 않음
