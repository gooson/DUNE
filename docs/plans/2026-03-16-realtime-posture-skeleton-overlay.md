---
topic: Phase 4A - 실시간 스켈레톤 + 각도 오버레이
date: 2026-03-16
status: draft
confidence: high
related_solutions:
  - architecture/2026-03-15-posture-assessment-vision-3d-pose.md
  - general/2026-03-16-posture-realtime-guidance.md
related_brainstorms:
  - 2026-03-16-realtime-video-posture-analysis.md
---

# Implementation Plan: 실시간 자세 분석 (Phase 4A)

## Context

현재 자세 분석은 정지 사진 촬영 → 3D 포즈 감지 → 분석 파이프라인이다.
실시간 카메라 피드에서 연속적으로 자세를 분석하여 스켈레톤 + 각도 오버레이를 표시하는 "실시간 분석 모드"를 추가한다.

기존 인프라:
- `PostureCaptureService`: AVCaptureSession + 2D 실시간 감지 (10fps) + 3D 정지 사진 감지
- `PostureAnalysisService`: 순수 SIMD 수학 (3D 관절 → 각도/비대칭 계산)
- `BodyGuideOverlay`: Canvas 기반 스켈레톤 렌더링

## Requirements

### Functional

- 실시간 카메라 피드에서 3D 포즈 감지를 주기적으로 수행 (3-5fps)
- 2D 연속 스켈레톤 오버레이 (기존 10fps → 30fps 목표)
- 주요 관절 각도를 실시간으로 오버레이 표시 (무릎 굴곡, 허리 기울기, 어깨 각도)
- 실시간 자세 점수 표시 (기존 PostureAnalysisService 재활용)
- 각도/점수의 색상 코딩 (정상=녹, 주의=황, 경고=적)

### Non-functional

- A17+ 전용 (최신 기기만)
- 2D 스켈레톤 30fps 유지 (프레임 드롭 < 5%)
- 3D 분석 최소 3fps
- 카메라 고정 (삼각대) 전제
- 배터리/발열 제한 없음 (초기)

## Approach

**듀얼 파이프라인**: 2D 연속 + 3D 주기적 감지를 병렬 수행.

2D 파이프라인은 매 프레임 스켈레톤 좌표를 제공하고, 3D 파이프라인은 주기적으로 정밀 분석 결과를 업데이트한다.
3D 결과 사이 구간은 2D 좌표 기반 각도 추정으로 보간한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 매 프레임 3D 감지 | 정확도 최고 | ~50-100ms/frame, 10fps도 불가 | 거부 |
| 2D만 사용 | 경량, 30fps 가능 | 깊이 정보 없어 정밀도 낮음 | 거부 |
| **듀얼 파이프라인** | 2D 연속 + 3D 주기적 → 부드러움+정밀도 | 구현 복잡도 증가 | **채택** |
| Metal/CoreML 커스텀 | 최적 성능 가능 | 개발 비용 매우 높음 | 거부 (Future) |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/RealtimePoseState.swift` | **New** | 실시간 분석 상태 모델 (관절 각도, 점수, 시계열 버퍼) |
| `Data/Services/RealtimePoseTracker.swift` | **New** | 듀얼 파이프라인 관리, 3D 샘플링, 시계열 버퍼 |
| `Data/Services/PostureCaptureService.swift` | **Modify** | 프레임 스로틀 조정, 3D 비디오 프레임 감지 메서드 추가 |
| `Domain/Services/PostureAnalysisService.swift` | **Modify** | 2D 좌표 기반 간이 각도 추정 메서드 추가 |
| `Presentation/Posture/RealtimePostureView.swift` | **New** | 실시간 분석 모드 전용 View |
| `Presentation/Posture/RealtimePostureViewModel.swift` | **New** | 실시간 분석 ViewModel |
| `Presentation/Posture/Components/AngleOverlay.swift` | **New** | 관절 각도 표시 오버레이 |
| `Presentation/Posture/Components/RealtimeScoreBadge.swift` | **New** | 실시간 점수 배지 |
| `DUNETests/RealtimePoseTrackerTests.swift` | **New** | 듀얼 파이프라인 로직 테스트 |
| `DUNETests/PostureAnalysisServiceTests.swift` | **Modify** | 2D 간이 각도 추정 테스트 추가 |

## Implementation Steps

### Step 1: Domain 모델 추가 — RealtimePoseState

- **Files**: `Domain/Models/RealtimePoseState.swift`
- **Changes**:
  - `RealtimeAngle`: 관절 각도 + 상태 (정상/주의/경고)
  - `RealtimePoseSnapshot`: 한 프레임의 2D keypoints + 추정 각도 + 타임스탬프
  - `RealtimePoseState`: 현재 점수, 최근 각도 배열, 3D 분석 결과 (optional)
- **Verification**: 컴파일 성공, 기존 모델과 import 충돌 없음

### Step 2: PostureAnalysisService 확장 — 2D 각도 추정

- **Files**: `Domain/Services/PostureAnalysisService.swift`, `DUNETests/PostureAnalysisServiceTests.swift`
- **Changes**:
  - `estimateAnglesFrom2D(keypoints:)` → 2D normalized 좌표에서 주요 각도 추정
  - 무릎 굴곡 (hip-knee-ankle 2D 각도)
  - 어깨 기울기 (좌우 어깨 y 차이)
  - 간이 forwardHead (nose-shoulder 수직 거리 비율)
  - 깊이 정보 없으므로 정확도는 3D 대비 낮음 → confidence 0.5 고정
- **Verification**: 단위 테스트 통과 (perfect posture → 정상, 왜곡 posture → 주의/경고)

### Step 3: PostureCaptureService 확장 — 3D 비디오 프레임 감지

- **Files**: `Data/Services/PostureCaptureService.swift`
- **Changes**:
  - `detectPoseFromVideoFrame(_ pixelBuffer: CVPixelBuffer) async throws -> PostureCaptureResult`
  - 기존 `detectPose(from: CGImage)` 로직을 CVPixelBuffer → CGImage 변환 후 재활용
  - 프레임 스로틀: 기존 `frameAnalysisInterval` 0.1 → configurable (2D용 0.033, 3D용 0.2-0.33)
  - `onRealtimeFrameUpdate` 콜백 추가 (2D keypoints + pixelBuffer 전달)
- **Verification**: 빌드 성공, 기존 가이던스 콜백 동작 유지

### Step 4: RealtimePoseTracker 서비스

- **Files**: `Data/Services/RealtimePoseTracker.swift`
- **Changes**:
  - `PostureCaptureService`를 래핑하여 듀얼 파이프라인 관리
  - 2D 파이프라인: 매 프레임 콜백에서 2D keypoints → `PostureAnalysisService.estimateAnglesFrom2D()`
  - 3D 파이프라인: 별도 Task에서 N프레임마다 3D 감지 → `PostureAnalysisService.analyzeFrontView/SideView()`
  - 시계열 버퍼: 최근 5초 (150 frames at 30fps) 관절 데이터 ring buffer
  - 점수 스무딩: 이동평균 (최근 10 samples)
  - 3D 감지 실패 시 2D 결과로 graceful degradation
  - 일시적 감지 실패: 마지막 유효 결과 300ms 유지
- **Verification**: 단위 테스트 (스무딩, 버퍼, degradation)

### Step 5: RealtimePostureViewModel

- **Files**: `Presentation/Posture/RealtimePostureViewModel.swift`
- **Changes**:
  - `@Observable @MainActor`
  - State: `isActive`, `currentAngles: [RealtimeAngle]`, `currentScore: Int`, `skeletonKeypoints`
  - `RealtimePoseTracker` 소유
  - `start()`: 카메라 시작 + 듀얼 파이프라인 활성화
  - `stop()`: 정리
  - 콜백 → MainActor dispatch → UI 업데이트
- **Verification**: 빌드 성공

### Step 6: AngleOverlay 컴포넌트

- **Files**: `Presentation/Posture/Components/AngleOverlay.swift`
- **Changes**:
  - Canvas 기반 각도 표시 (관절 위치에 호(arc) + 숫자)
  - 색상 코딩: normal(녹), caution(황), warning(적)
  - 기존 `BodyGuideOverlay.visionToScreen()` 좌표 변환 재활용
  - 표시 각도: 무릎 굴곡, 어깨 기울기, 허리 각도
- **Verification**: Preview에서 시각적 확인

### Step 7: RealtimeScoreBadge 컴포넌트

- **Files**: `Presentation/Posture/Components/RealtimeScoreBadge.swift`
- **Changes**:
  - 실시간 점수 배지 (0-100, 색상 그라데이션)
  - 점수 변화 애니메이션 (숫자 카운터)
  - 화면 상단 고정
- **Verification**: Preview에서 시각적 확인

### Step 8: RealtimePostureView

- **Files**: `Presentation/Posture/RealtimePostureView.swift`
- **Changes**:
  - CameraPreviewView + BodyGuideOverlay (기존 재활용) + AngleOverlay + RealtimeScoreBadge
  - 시작/종료 버튼
  - 정면/측면 전환
  - `.task`에서 ViewModel.start(), `.onDisappear`에서 stop()
- **Verification**: 시뮬레이터에서 카메라 프리뷰 + 오버레이 확인

### Step 9: 진입점 연결

- **Files**: 기존 Posture 진입점 (PostureHistoryView 또는 WellnessView에서 접근)
- **Changes**:
  - "실시간 분석" 버튼 추가 → sheet/fullScreenCover로 RealtimePostureView 표시
- **Verification**: 탭 → 실시간 모드 진입 → 카메라 + 오버레이 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 프레임 드롭 (3D 지연) | 2D 결과로 graceful degradation, 3D 결과 도착 시 업데이트 |
| 일시적 사람 미감지 | 마지막 유효 결과 300ms 유지 후 스켈레톤 숨김 |
| 다중 인물 | 가장 큰 바운딩박스 1명만 추적 (기존 패턴) |
| 역광/저조도 | 기존 LightingStatus 재활용 + 경고 표시 |
| A16 이하 기기 | `ProcessInfo.processInfo.isiOSAppOnMac` + chip 체크로 비활성화 |
| 백그라운드 전환 | scenePhase 감지 → 카메라 중지 |

## Testing Strategy

- **Unit tests**:
  - `PostureAnalysisService.estimateAnglesFrom2D()`: 정자세/왜곡 케이스
  - `RealtimePoseTracker`: 스무딩 로직, 링 버퍼, 3D 실패 시 degradation
- **Manual verification**:
  - 시뮬레이터에서 카메라 프리뷰 + 오버레이 렌더링 확인
  - 실기기에서 3D fps 벤치마크 (A17 Pro 기준 최소 3fps)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 3D 감지 fps 부족 | 중 | 높 | 2D fallback으로 UX 유지, 3D 주기 동적 조절 |
| 메모리 사용량 증가 | 낮 | 중 | 링 버퍼 크기 제한 (5초), CVPixelBuffer 즉시 해제 |
| 발열 | 중 | 중 | 초기엔 무시, 문제 시 adaptive fps 도입 |
| 기존 캡처 모드 regression | 낮 | 높 | 기존 코드 수정 최소화, 새 서비스/뷰로 분리 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 인프라 (카메라, 2D 감지, 분석 서비스, Canvas 오버레이)를 대부분 재활용. 새로 구현하는 부분은 3D 비디오 프레임 감지 + 듀얼 파이프라인 스케줄링 + 각도 오버레이 UI. Vision API 동작은 기존 solution docs에서 검증 완료.
