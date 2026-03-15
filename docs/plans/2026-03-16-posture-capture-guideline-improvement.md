---
topic: posture-capture-guideline-improvement
date: 2026-03-16
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-15-posture-assessment-vision-3d-pose.md
  - docs/solutions/general/2026-03-15-posture-photo-orientation-zoom-nav.md
related_brainstorms:
  - docs/brainstorms/2026-03-16-posture-capture-guideline-improvement.md
---

# Implementation Plan: Posture 촬영 가이드라인 개선

## Context

현재 posture 촬영 가이드가 점선 실루엣 + 간단한 텍스트만 제공하여 사용자가 정확한 위치/거리를 잡지 못하고 재촬영이 잦음. 실시간 피드백, 거리/조명 감지, 후면 카메라 + TTS, 자동 촬영을 추가하여 첫 시도 성공률을 대폭 개선한다.

## Requirements

### Functional

- 실시간 2D pose 감지로 전신/거리/안정 상태를 피드백
- 존 기반 가이드 오버레이 (점선 실루엣 교체)
- 실시간 skeleton 오버레이 (프리뷰에서 관절 표시)
- 거리 인디케이터 (전신이 화면 60-80% 차지 시 optimal)
- 조명 감지 + 경고
- 모든 조건 충족 시 자동 카운트다운 (수동 버튼도 유지)
- 후면 카메라 지원 + 카메라 전환 버튼
- 후면 카메라 시 TTS 음성 카운트다운

### Non-functional

- 2D pose detection: 최대 10fps (배터리/발열 고려)
- 감지 결과 debounce: 300ms 이상 안정 시에만 UI 업데이트
- 기존 3D pose 최종 촬영 파이프라인 유지 (정확도 보존)
- Swift 6 Sendable 준수

## Approach

**레이어드 접근**: Data layer에 실시간 감지 서비스 추가 → Domain에 GuidanceState 모델 → Presentation에 가이드 오버레이 + ViewModel 확장.

기존 `PostureCaptureService`에 `AVCaptureVideoDataOutput` 추가하여 실시간 프레임 분석. 최종 촬영은 기존 `AVCapturePhotoOutput` 유지.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 3D pose를 실시간에도 사용 | 깊이 정보 포함 | 50-100ms/프레임, 배터리 소모 과다 | 거부 |
| 2D pose 실시간 + 3D 최종 | 경량 가이드 + 정밀 최종 | 두 API 동시 관리 | **채택** |
| ARKit 기반 거리 측정 | 정확한 거리 | LiDAR 없는 기기 미지원 | 거부 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/PostureGuidance.swift` | **New** | GuidanceState, DistanceStatus, LightingStatus 모델 |
| `DUNE/Data/Services/PostureCaptureService.swift` | **Modify** | AVCaptureVideoDataOutput 추가, 카메라 position 전환, 실시간 2D pose 감지 |
| `DUNE/Data/Services/PostureGuidanceAnalyzer.swift` | **New** | 실시간 2D pose → GuidanceState 변환 로직 |
| `DUNE/Presentation/Posture/PostureAssessmentViewModel.swift` | **Modify** | GuidanceState 관리, 자동 카운트다운, TTS, 카메라 전환 |
| `DUNE/Presentation/Posture/PostureCaptureView.swift` | **Modify** | 새 가이드 오버레이, 카메라 전환 버튼, 체크리스트 UI |
| `DUNE/Presentation/Posture/Components/BodyGuideOverlay.swift` | **Rewrite** | 존 기반 가이드 + 실시간 skeleton 오버레이 |
| `DUNE/Presentation/Posture/Components/GuidanceChecklistView.swift` | **New** | 실시간 체크리스트 UI (전신/거리/안정/조명) |
| `DUNE/Presentation/Posture/Components/DistanceIndicatorView.swift` | **New** | 거리 인디케이터 바 |
| `DUNETests/PostureGuidanceAnalyzerTests.swift` | **New** | GuidanceAnalyzer 유닛 테스트 |
| `Shared/Resources/Localizable.xcstrings` | **Modify** | 새 가이드 문자열 en/ko/ja |

## Implementation Steps

### Step 1: Domain 모델 — GuidanceState

- **Files**: `DUNE/Domain/Models/PostureGuidance.swift`
- **Changes**: `GuidanceState`, `DistanceStatus`, `LightingStatus`, `CameraPosition` enum/struct 정의
- **Verification**: 컴파일 확인, Sendable 준수

### Step 2: Data — 실시간 2D Pose 감지 + 카메라 전환

- **Files**: `DUNE/Data/Services/PostureCaptureService.swift`
- **Changes**:
  - `AVCaptureVideoDataOutput` 추가 + `AVCaptureVideoDataOutputSampleBufferDelegate`
  - `setupCamera(position:)` 파라미터 추가 (front/back)
  - `switchCamera()` 메서드 (세션 재구성)
  - 프레임 콜백에서 `VNDetectHumanBodyPoseRequest` (2D) 실행
  - 프레임 throttle: 100ms 간격 (10fps)
  - `onGuidanceUpdate: @Sendable (GuidanceState) -> Void` 콜백
- **Verification**: 카메라 전환 동작, 2D pose 감지 로그 확인

### Step 3: Data — GuidanceAnalyzer

- **Files**: `DUNE/Data/Services/PostureGuidanceAnalyzer.swift`
- **Changes**:
  - 2D pose observations → GuidanceState 변환
  - 전신 보임: ankle 관절 감지 여부
  - 거리: head-ankle 비율 (normalized) → DistanceStatus
  - 안정: 연속 5프레임(500ms) 관절 변동 < threshold
  - 조명: 프레임 평균 luminance 계산
  - 정면/측면 판별: shoulder 폭 비율
  - 팔 위치: wrist-hip 거리
- **Verification**: 유닛 테스트 (Step 8)

### Step 4: ViewModel 확장 — GuidanceState + 자동 카운트다운 + TTS

- **Files**: `DUNE/Presentation/Posture/PostureAssessmentViewModel.swift`
- **Changes**:
  - `PostureCapturePhase` 변경: `.guiding` → `.preparing(GuidanceState)`
  - `guidanceState: GuidanceState` 프로퍼티 추가
  - `isAutoCapture: Bool` (기본 true)
  - 모든 체크리스트 충족 + 2초 유지 → 자동 `startCountdown()`
  - 카운트다운 중 pose 유실 → 취소 + preparing 복귀
  - `switchCamera()` 메서드
  - `AVSpeechSynthesizer` 기반 TTS (후면 카메라 시 음성 카운트다운)
  - `cameraPosition: CameraPosition` 상태
- **Verification**: 상태 전환 로직 확인

### Step 5: UI — BodyGuideOverlay 재작성 (존 기반)

- **Files**: `DUNE/Presentation/Posture/Components/BodyGuideOverlay.swift`
- **Changes**:
  - 점선 실루엣 제거
  - 존 기반 가이드: 중앙 영역에 반투명 테두리 (충족 시 녹색, 미충족 시 흰색)
  - 발 위치 마커 유지 (발바닥 아이콘으로 교체)
  - 실시간 skeleton 오버레이: 2D pose 관절을 프리뷰에 실시간 렌더링
  - 관절 연결선 + 관절 점 표시
- **Verification**: 시뮬레이터에서 가이드 표시 확인

### Step 6: UI — GuidanceChecklistView + DistanceIndicator

- **Files**: `DUNE/Presentation/Posture/Components/GuidanceChecklistView.swift`, `DistanceIndicatorView.swift`
- **Changes**:
  - 체크리스트: SF Symbol 기반 4항목 (전신 ✓, 거리 ✓, 안정 ✓, 조명 ✓)
  - 미충족 항목에 텍스트 힌트 표시
  - 거리 인디케이터: 좌측 세로 바 (tooFar/slightlyFar/optimal/tooClose)
  - GuidanceState binding으로 실시간 업데이트
- **Verification**: 시뮬레이터에서 UI 표시 확인

### Step 7: UI — PostureCaptureView 통합 + 카메라 전환 + 상황별 힌트

- **Files**: `DUNE/Presentation/Posture/PostureCaptureView.swift`
- **Changes**:
  - `phaseOverlay`에 `.preparing` 케이스 추가
  - 카메라 전환 버튼 (toolbar)
  - 자동/수동 촬영 토글
  - 상황별 텍스트 힌트 (GuidanceState 기반)
  - 후면 카메라 시 미러링 해제
- **Verification**: 전체 촬영 플로우 시뮬레이터 확인

### Step 8: 테스트 + Localization

- **Files**: `DUNETests/PostureGuidanceAnalyzerTests.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - GuidanceAnalyzer 유닛 테스트: 거리 판정, 안정 판정, 조명 판정, 전신 감지
  - 새 UI 문자열 en/ko/ja 번역 등록
- **Verification**: `xcodebuild test`, 빌드 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 조명 극도로 부족 | LightingStatus.tooLow → 경고 표시, 촬영 버튼은 활성 유지 (사용자 판단) |
| 여러 사람 감지 | 2D pose 결과 중 confidence 최고인 1개만 사용 |
| ankle 미감지 | isFullBodyVisible = false + "발끝이 보이도록..." 힌트 |
| 카메라 전환 중 | captureSession.beginConfiguration() 동안 guiding 일시정지 |
| 후면 카메라 + 화면 안 보임 | TTS로 "준비됨, 3, 2, 1, 촬영" 음성 제공 |
| 자동 카운트다운 중 pose 유실 | 즉시 카운트다운 취소 → preparing 복귀 |
| 전면 미러링 vs 후면 | 전면: mirrored preview, 후면: 정상 방향. 좌우 관절 명칭 주의 |
| AVSpeechSynthesizer 실패 | 무음으로 fallback (TTS는 best-effort) |

## Testing Strategy

- Unit tests: `PostureGuidanceAnalyzerTests` — 거리/안정/조명/전신 판정 로직
- Integration: ViewModel 상태 전환 테스트 (기존 `PostureAssessmentViewModelTests` 확장)
- Manual: 시뮬레이터에서 전체 플로우 확인 (카메라는 시뮬레이터 제한)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 2D pose 실시간 성능 | Low | Medium | 10fps throttle, background queue |
| AVCaptureVideoDataOutput + PhotoOutput 동시 사용 | Low | High | Apple 공식 지원 조합, sessionPreset .photo 유지 |
| TTS 지연으로 카운트다운 불일치 | Medium | Low | 사운드 + 진동 병행, TTS는 보조 |
| 전면/후면 전환 시 세션 불안정 | Low | Medium | beginConfiguration/commitConfiguration 래핑 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 2D pose (VNDetectHumanBodyPoseRequest)는 경량이고 잘 문서화됨. AVCaptureVideoDataOutput + PhotoOutput 동시 사용은 표준 패턴. TTS는 AVSpeechSynthesizer로 간단 구현. 기존 3D 촬영 파이프라인을 변경하지 않아 리스크 낮음.
