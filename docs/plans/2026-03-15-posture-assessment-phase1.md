---
topic: posture-assessment-phase1
date: 2026-03-15
status: draft
confidence: high
related_solutions: []
related_brainstorms: [2026-03-15-posture-assessment-system.md]
---

# Implementation Plan: Posture Assessment Phase 1 — Core Measurement Engine

## Context

사용자의 자세를 카메라로 측정하여 체형 평가 점수를 제공하는 시스템의 코어 엔진. Vision 3D Pose (iOS 18+ Swift API: `DetectHumanBodyPose3DRequest`)를 사용하여 전면/측면 사진에서 17개 관절의 3D 좌표를 추출하고, 8개 자세 지표를 산출한다.

Phase 1은 데이터 수집/분석 파이프라인에 집중한다. 점수화/시각화/히스토리는 후속 Phase에서 구현.

## Requirements

### Functional

- 카메라 캡처 → Vision 3D Pose → 관절 좌표 추출
- 전면(front) + 측면(side) 2장 촬영 UX (타이머 셀프모드)
- 촬영 가이드 오버레이 (전신 실루엣, 발 위치)
- 8개 자세 지표 산출 (거북목, 굽은 어깨, 흉추 과만곡, 어깨 비대칭, 골반 비대칭, 무릎 정렬, 체간 측방 이동, 무릎 과신전)
- 종합 Posture Score (0-100, 가중 복합)
- 촬영 품질 검증 (전신 감지, confidence 임계값)
- 복수 프레임 평균화 (안정성)
- 측정 결과 + 원본 사진 저장 (SwiftData)
- 결과 화면: 지표별 정상/주의/위험 + 관절 오버레이

### Non-functional

- 완전 온디바이스 처리 (서버 전송 없음)
- 촬영 → 분석 결과 10초 이내
- 재현성: 동일 조건 재촬영 시 ±5% 이내
- 카메라 권한 요청 (NSCameraUsageDescription)
- 3개 언어 지원 (en/ko/ja)

## Approach

**Vision 3D Pose (iOS 18+ Swift API)** 사용.

- `DetectHumanBodyPose3DRequest` + async/await
- 사진 캡처 모드 (비디오 프레임이 아닌 고해상도 정지 사진)
- 전면 카메라 (셀프 촬영) + 타이머
- 관절 좌표는 미터 단위 `simd_float4x4` → `SIMD3<Float>` 추출
- Domain 레이어는 순수 좌표 입력만 받음 (Vision import 금지)

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Vision 3D Pose (iOS 18+) | async/await, 전면 카메라, 미터 단위 | iOS 18+ 필수 | **선택** (앱 타겟 iOS 26) |
| ARKit Body Tracking | 91개 관절, 월드 앵커링 | 후면 카메라만, AR 오버헤드 | 기각 |
| MediaPipe Pose | 33개 관절, 크로스플랫폼 | 3rd party, 모델 번들링 | 기각 |
| Vision 2D Pose | 가벼움, iOS 14+ | 깊이 정보 없음, 절대 거리 측정 불가 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/PostureMetric.swift` | New | 자세 지표 enum + 측정값 구조체 |
| `Domain/Models/PostureAssessment.swift` | New | 자세 평가 도메인 모델 (점수, 지표 집합) |
| `Domain/Services/PostureAnalysisService.swift` | New | 3D 좌표 → 자세 지표 변환 순수 함수 |
| `Data/Persistence/Models/PostureAssessmentRecord.swift` | New | SwiftData @Model |
| `Data/Persistence/Migration/AppSchemaVersions.swift` | Modify | V16 추가 + migration |
| `Data/Services/PostureCaptureService.swift` | New | AVCaptureSession + Vision 3D Pose |
| `Presentation/Posture/PostureCaptureView.swift` | New | 카메라 UI + 가이드 오버레이 |
| `Presentation/Posture/PostureResultView.swift` | New | 분석 결과 + 관절 오버레이 시각화 |
| `Presentation/Posture/PostureAssessmentViewModel.swift` | New | @Observable ViewModel |
| `Presentation/Posture/Components/BodyGuideOverlay.swift` | New | 촬영 가이드 실루엣 |
| `Presentation/Posture/Components/JointOverlayView.swift` | New | 관절 포인트 + 연결선 오버레이 |
| `Presentation/Shared/Extensions/PostureMetric+View.swift` | New | displayName, color, icon 등 |
| `Presentation/Wellness/WellnessView.swift` | Modify | Posture 카드 추가 |
| `DUNE/project.yml` | Modify | NSCameraUsageDescription 추가 |
| `Shared/Resources/Localizable.xcstrings` | Modify | 자세 관련 문자열 en/ko/ja |
| `DUNETests/PostureAnalysisServiceTests.swift` | New | 좌표→지표 변환 유닛 테스트 |
| `DUNETests/PostureAssessmentViewModelTests.swift` | New | ViewModel validation 테스트 |

## Implementation Steps

### Step 1: Domain Models (PostureMetric, PostureAssessment)

- **Files**: `Domain/Models/PostureMetric.swift`, `Domain/Models/PostureAssessment.swift`
- **Changes**:
  - `PostureMetricType` enum: 8개 자세 지표 타입 (forwardHead, roundedShoulders, thoracicKyphosis, shoulderAsymmetry, hipAsymmetry, kneeAlignment, lateralShift, kneeHyperextension)
  - `PostureMetricResult`: 개별 지표 측정 결과 (type, value, unit, status: normal/caution/warning, confidence)
  - `PostureAssessment`: 전체 평가 결과 (metrics: [PostureMetricResult], overallScore: Int, captureType: front/side, jointPositions: [JointPosition3D])
  - `JointPosition3D`: 관절 이름 + SIMD3<Float> 위치 (Sendable)
  - `PostureStatus` enum: normal, caution, warning (각 지표별)
  - **Domain은 Foundation만 import** (simd는 Foundation에 포함)
- **Verification**: 컴파일 성공, Domain에 SwiftUI/Vision import 없음

### Step 2: PostureAnalysisService (Domain, 순수 함수)

- **Files**: `Domain/Services/PostureAnalysisService.swift`
- **Changes**:
  - 입력: `[JointPosition3D]` (관절 이름 → 3D 위치 딕셔너리)
  - 출력: `[PostureMetricResult]`
  - 각 지표별 계산 함수:
    - `measureForwardHead()`: centerHead vs centerShoulder Z축 변위
    - `measureRoundedShoulders()`: shoulder vs spine Z축 변위
    - `measureThoracicKyphosis()`: centerShoulder + spine + root 3점 각도
    - `measureShoulderAsymmetry()`: leftShoulder vs rightShoulder Y차이
    - `measureHipAsymmetry()`: leftHip vs rightHip Y차이
    - `measureKneeAlignment()`: hip-knee-ankle 전면 Q각
    - `measureLateralShift()`: centerHead vs root X축 편차
    - `measureKneeHyperextension()`: hip-knee-ankle 측면 각도
  - 종합 점수 계산: 가중 복합 (Tier 1: 60%, Tier 2: 30%, Tier 3: 10%)
  - `angleBetweenJoints()`, `distanceBetween()` 헬퍼
  - **모든 계산에 isFinite guard** (NaN/Infinity 방어)
- **Verification**: 유닛 테스트로 알려진 좌표 → 예상 각도/거리 검증

### Step 3: PostureAssessmentRecord (SwiftData)

- **Files**: `Data/Persistence/Models/PostureAssessmentRecord.swift`, `Data/Persistence/Migration/AppSchemaVersions.swift`
- **Changes**:
  - `PostureAssessmentRecord` @Model:
    - id: UUID, date: Date, captureTypeRaw: String (front/side)
    - overallScore: Int, metricsJSON: String (JSON encoded [PostureMetricResult])
    - jointPositionsJSON: String (JSON encoded [JointPosition3D])
    - frontImageData: Data?, sideImageData: Data? (원본 사진 JPEG)
    - bodyHeight: Double? (미터)
    - heightEstimationRaw: String (measured/reference)
    - memo: String, createdAt: Date
  - V16 스키마 추가: `AppSchemaV16` with PostureAssessmentRecord
  - V15→V16 lightweight migration
  - `AppMigrationPlan.currentSchema` → V16 업데이트
- **Verification**: 앱 삭제 → 설치 → 실행 → 종료 → 재실행 (CloudKit 스키마 검증)

### Step 4: PostureCaptureService (Data, 카메라 + Vision)

- **Files**: `Data/Services/PostureCaptureService.swift`
- **Changes**:
  - `PostureCaptureService`: @Observable 카메라 관리자
    - AVCaptureSession 설정 (전면 카메라, 고해상도 사진)
    - `AVCapturePhotoOutput` for still photo capture
    - 타이머 촬영 (3초 카운트다운)
    - 촬영 후 `DetectHumanBodyPose3DRequest` 실행
    - 3D 관절 좌표 추출 → `[JointPosition3D]` 변환
    - 복수 프레임 평균화 (3장 촬영 → 중앙값)
    - 품질 검증: 전신 감지 여부, bodyHeight 유효성
    - `pointInImage()` for 2D projection (오버레이 용)
  - Protocol: `PostureCapturing` (테스트 목 가능)
- **Verification**: 시뮬레이터에서 카메라 초기화 확인 (실제 포즈 감지는 실기기 필요)

### Step 5: PostureAssessmentViewModel

- **Files**: `Presentation/Posture/PostureAssessmentViewModel.swift`
- **Changes**:
  - `@Observable @MainActor` 패턴 (BodyCompositionViewModel 따름)
  - 상태: capturePhase (idle/guiding/countdown/capturing/analyzing/result)
  - captureType: front/side 전환
  - frontAssessment / sideAssessment 결과 저장
  - `createValidatedRecord() -> PostureAssessmentRecord?`
  - `validateAssessment()`: 양쪽 촬영 완료 확인, 최소 confidence 검증
  - `resetCapture()`: 재촬영
  - `isSaving` / `didFinishSaving()` 패턴
- **Verification**: 유닛 테스트 — 상태 전이, 검증 분기

### Step 6: PostureCaptureView (카메라 UI)

- **Files**: `Presentation/Posture/PostureCaptureView.swift`, `Presentation/Posture/Components/BodyGuideOverlay.swift`
- **Changes**:
  - 카메라 프리뷰 (`AVCaptureVideoPreviewLayer` in `UIViewRepresentable`)
  - 전신 실루엣 가이드 오버레이 (반투명 인체 윤곽)
  - 발 위치 마커
  - 촬영 모드 표시 (전면/측면)
  - 3초 카운트다운 애니메이션
  - 품질 피드백 (전신이 보이는지 실시간 표시)
  - 촬영 완료 → 분석 중 로딩 상태
  - 전면 촬영 완료 → "측면으로 돌아서세요" 안내 → 측면 촬영
- **Verification**: 시뮬레이터에서 UI 렌더링 확인, 상태 전이 확인

### Step 7: PostureResultView (결과 + 오버레이)

- **Files**: `Presentation/Posture/PostureResultView.swift`, `Presentation/Posture/Components/JointOverlayView.swift`, `Presentation/Shared/Extensions/PostureMetric+View.swift`
- **Changes**:
  - 전면/측면 사진 위 관절 포인트 + 연결선 오버레이
  - Plumb line (이상 정렬선) 표시
  - 종합 점수 (큰 원형 게이지)
  - 지표별 카드 (정상=초록, 주의=노랑, 위험=빨강)
  - 각 지표 탭 → 상세 설명 + 측정값 표시
  - PostureMetric+View.swift: displayName, color, iconName, description
  - 저장 버튼 → createValidatedRecord → modelContext.insert
- **Verification**: 시뮬레이터에서 모의 데이터로 UI 확인

### Step 8: Wellness 탭 통합 + project.yml

- **Files**: `Presentation/Wellness/WellnessView.swift`, `DUNE/project.yml`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - WellnessView Physical 섹션에 "Posture Assessment" 카드 추가
  - 카드 탭 → PostureCaptureView sheet 열기
  - 최근 점수 표시 (없으면 "측정하기" CTA)
  - project.yml: `INFOPLIST_KEY_NSCameraUsageDescription` 추가
  - Localizable.xcstrings: 모든 새 문자열 en/ko/ja 등록
- **Verification**: 빌드 성공, Wellness 탭에서 카드 표시 확인

### Step 9: Unit Tests

- **Files**: `DUNETests/PostureAnalysisServiceTests.swift`, `DUNETests/PostureAssessmentViewModelTests.swift`
- **Changes**:
  - PostureAnalysisService 테스트:
    - 알려진 좌표 → 예상 각도 (오차 ±1°)
    - 완벽한 자세 → 100점
    - 극단적 거북목 → 낮은 점수
    - NaN/Infinity 입력 → 안전한 fallback
    - 관절 누락 → 해당 지표만 측정 불가
  - ViewModel 테스트:
    - createValidatedRecord — 양쪽 촬영 미완료 시 nil
    - isSaving 중복 방지
    - resetCapture 상태 초기화
    - capturePhase 전이 검증
- **Verification**: `xcodebuild test` 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 전신이 프레임에 안 들어옴 | 실시간 감지 피드백 + 재촬영 유도 텍스트 |
| 관절 confidence 미달 | 해당 지표 `.unmeasurable` 상태, 부분 결과 제공 |
| 옷이 두꺼움 | 타이트한 옷 권장 안내 (촬영 전 가이드) |
| 카메라 권한 거부 | 설정 앱으로 유도하는 에러 화면 |
| bodyHeight가 reference (1.8m) | heightEstimation 표시, 절대 거리 대신 비율 기반 분석 |
| 바닥 기울기 | ankle 기준선 보정 (양 발목의 Y좌표 차이 보정) |
| 사진 저장 용량 | JPEG 0.7 압축, 최대 1MB/장 |
| 두 명 이상 감지 | 가장 prominent한 1명만 분석 (Vision 기본 동작) |

## Testing Strategy

- **Unit tests**: PostureAnalysisService (좌표→지표 변환, 경계값, NaN), ViewModel (상태 전이, 검증)
- **Integration tests**: 면제 (Vision 3D Pose는 실기기 필요)
- **Manual verification**: 실기기에서 전면/측면 촬영 → 결과 확인, 재촬영 재현성 검증

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Vision 3D Pose 정확도가 부족 | 중 | 높 | 복수 프레임 평균화, confidence 임계값, 정상 범위 넓게 설정 |
| 시뮬레이터에서 테스트 불가 | 높 | 중 | Mock 데이터로 UI/로직 검증, 실기기 테스트는 수동 |
| 사진 저장 용량 증가 | 낮 | 낮 | JPEG 압축, 향후 자동 삭제 정책 |
| SwiftData V16 migration 실패 | 낮 | 높 | lightweight migration (새 모델 추가만), 앱 삭제 후 재설치 테스트 |
| 카메라 권한 UX 복잡 | 낮 | 중 | 촬영 전 권한 상태 확인 + 설정 유도 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 BodyComposition/Injury 패턴을 정확히 따르며, Vision 3D Pose API는 공식 문서와 WWDC 세션으로 충분히 검증됨. SwiftData migration은 lightweight (새 모델 추가)로 위험 낮음. 가장 큰 불확실성은 Vision 정확도이나, 이는 Phase 1 구현 후 실기기 테스트로 검증 가능.
