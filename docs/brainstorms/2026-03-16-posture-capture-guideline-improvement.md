---
tags: [posture, camera, guide, real-time-feedback, vision-api, ux]
date: 2026-03-16
category: brainstorm
status: draft
---

# Brainstorm: Posture 촬영 가이드라인 개선

## Problem Statement

현재 posture 촬영 가이드가 사용자에게 충분한 안내를 제공하지 못함:

1. **실루엣이 애매함**: 점선 다이어그램만으로는 정확한 위치를 잡기 어려움. 머리 원에 맞추려다 몸이 프레임 밖으로 나감
2. **거리감 부족**: 카메라에서 얼마나 떨어져야 하는지 알 수 없음. 너무 가까우면 전신이 안 보이고, 너무 멀면 정확도 저하
3. **실패율**: 가이드에 맞춰도 pose detection 실패 → 재촬영 반복
4. **전면 카메라 한정**: 셀프 촬영만 가능, 후면 카메라+타이머 미지원

## Target Users

- DUNE 앱의 자세 분석 기능 사용자
- 혼자서 촬영하는 일반 사용자 (도와줄 사람 없는 경우가 대부분)
- 운동 전후 자세 변화를 추적하려는 피트니스 사용자

## Success Criteria

1. 첫 시도 성공률 80% 이상 (현재 체감 50% 미만)
2. 가이드 없이도 "어디 서야 하는지" 직관적으로 파악 가능
3. 후면 카메라 지원으로 더 높은 화질/정확도 확보
4. 조명/거리 문제로 인한 실패를 사전 차단

## Proposed Approach

### A. 실루엣/오버레이 비주얼 개선

#### 현재 문제
- `BodyGuideOverlay`: 점선 실루엣 + 발 마커만 존재
- 머리 원형이 실제 머리 크기/위치와 안 맞음 → 머리에 맞추면 몸이 잘림
- 정면/측면 가이드가 너무 추상적

#### 개선안

**1. 동적 가이드 영역 (Zone-based Guide)**
```
┌─────────────────────┐
│  ❌ 머리 원에 맞추기  │  → 폐기
│                     │
│  ✅ "전신 존" 표시    │  → 채택
│  ┌─ ─ ─ ─ ─ ─ ─┐  │
│  │  Head zone   │  │  ← 상단 15%
│  │  Body zone   │  │  ← 중앙 70%
│  │  Feet zone   │  │  ← 하단 15%
│  └─ ─ ─ ─ ─ ─ ─┘  │
└─────────────────────┘
```
- 머리 원 대신 "전신이 이 영역 안에 들어오면 OK" 존 표시
- 존 안에 들어오면 초록색, 밖이면 빨간색 테두리

**2. 반투명 실루엣 교체**
- 점선 → 반투명 그라디언트 인체 실루엣 (이미지 기반)
- 정면/측면 각각 자연스러운 포즈 이미지
- 실루엣에 맞추는 게 아니라 "대략 이 범위" 참고용

**3. 발 위치 강조**
- 현재 24pt 원형 마커 → 발바닥 모양 아이콘 + 어깨너비 거리 표시
- 바닥 라인(수평선) 추가로 수평 기준 제공

### B. 실시간 피드백 시스템

#### 기술 기반
- `VNDetectHumanBodyPoseRequest` (2D) — 프리뷰 프레임에서 실시간 감지
- 3D 분석(`VNDetectHumanBodyPose3DRequest`)은 최종 촬영 시에만 사용 (비용 높음)

#### 피드백 항목

| 피드백 | 감지 방법 | UI 표시 |
|--------|----------|---------|
| 전신 보임 여부 | ankle joint 감지 유무 | "발끝이 보이도록 뒤로 이동하세요" |
| 거리 적정 여부 | head~ankle 거리 비율 | "조금 더 가까이/멀리 서세요" |
| 자세 안정 여부 | 연속 N프레임 joint 변동 | 안정되면 자동 카운트다운 |
| 정면/측면 판별 | shoulder width vs depth | "정면/측면을 향해주세요" |
| 팔 위치 | wrist-hip 거리 | "팔을 자연스럽게 내려주세요" |

#### 구현 아키텍처

```
CameraPreview
  ├── AVCaptureVideoDataOutput (실시간 프레임)
  │     └── VNDetectHumanBodyPoseRequest (2D, 경량)
  │           └── GuidanceState 업데이트
  │
  ├── GuidanceOverlay (피드백 UI)
  │     ├── 체크리스트 아이콘 (✓ 전신 보임, ✓ 거리 OK, ✓ 자세 안정)
  │     └── 텍스트 힌트 ("조금 뒤로...")
  │
  └── AVCapturePhotoOutput (최종 촬영)
        └── VNDetectHumanBodyPose3DRequest (3D, 정밀)
```

#### 자동 캡처 트리거
- 모든 체크리스트 충족 + 3초 안정 유지 → 자동 카운트다운 시작
- 수동 촬영 버튼도 유지 (체크리스트 미충족 시 경고 후 촬영 허용)

### C. 텍스트/인스트럭션 개선

#### 현재 문제
- 단일 텍스트: "Stand facing the camera with your full body visible."
- 문제 발생 시 구체적 안내 없음

#### 개선안

**1. 단계별 온보딩 (첫 사용 시)**
```
Step 1: 📱 "폰을 안정적인 곳에 세워주세요" (후면 카메라 시)
Step 2: 🦶 "발 마커 위치에 서주세요"
Step 3: 👤 "전신이 화면에 보이는지 확인하세요"
Step 4: 🔄 "초록색 체크가 모두 켜지면 자동 촬영됩니다"
```

**2. 상황별 힌트 (실시간 피드백과 연동)**
- 전신 미감지: "화면에 전신이 보이도록 카메라에서 떨어져 주세요"
- 너무 멀리: "조금 더 가까이 다가와 주세요"
- 자세 불안정: "잠시 가만히 서 주세요"
- 조명 부족: "더 밝은 곳으로 이동해 주세요"
- 측면 촬영 시: "어깨가 카메라를 향하도록 90도 돌아주세요"

**3. 시각적 인스트럭션 (이미지/아이콘)**
- Good/Bad 예시 이미지 (첫 사용 온보딩)
- SF Symbol 기반 체크리스트 아이콘

### D. 거리/조명 가이드

#### 거리 감지
- 2D pose의 head-ankle 비율로 추정 (normalized image coordinates)
- 이상적 비율: 전신이 화면 높이의 60~80% 차지
- 근거: Vision API 정확도는 전신이 프레임의 60-80%일 때 최적

```swift
// 거리 판정 로직 (2D pose 기반)
let bodyRatio = (ankleY - headY) // normalized 0-1
switch bodyRatio {
case ..<0.4: .tooFar      // 전신이 화면 40% 미만
case 0.4..<0.6: .slightlyFar
case 0.6..<0.8: .optimal  // 최적 범위
case 0.8...: .tooClose    // 전신이 화면 80% 초과
}
```

#### 조명 감지
- `AVCaptureDevice.iso` + `exposureDuration` 기반 밝기 추정
- 또는 프레임 평균 밝기(luminance) 계산
- 임계값 이하 시 "조명이 부족합니다" 경고

#### UI 표시
- 거리 인디케이터: 좌측 세로 바 (녹색 존 = 최적 거리)
- 조명 인디케이터: 우측 상단 아이콘 (☀️ OK / ⚠️ 부족)

### E. 후면 카메라 + 타이머 지원

#### 사용 시나리오
- 폰을 테이블/삼각대에 세움 → 후면 카메라로 고화질 촬영
- 전면 카메라보다 해상도/AF 우수 → pose detection 정확도 향상

#### 구현

**카메라 전환**
```swift
// PostureCaptureService에 position 파라미터 추가
func setupCamera(position: AVCaptureDevice.Position = .front) throws {
    let device = AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: position
    )
    // ...
}
```

**후면 카메라 타이머 플로우**
```
[카메라 전환 버튼] → 후면 카메라 활성화
  → 실시간 2D pose 감지 시작
  → 전신 감지 + 안정 → 음성/진동 알림 "3, 2, 1"
  → 촬영
  → 결과 표시
```

**미러링 처리**
- 전면 카메라: 미러링 O (사용자 기대대로)
- 후면 카메라: 미러링 X (실제 방향)
- 좌우 관절 명칭 주의 (이미지 좌우 반전 영향)

**음성 카운트다운**
- 후면 카메라 시 화면을 못 보므로 음성/소리 피드백 필수
- `AVSpeechSynthesizer` 또는 시스템 사운드
- "전신이 감지되었습니다. 3... 2... 1... 촬영!"

### F. 전체 촬영 플로우 재설계

#### 현재 플로우
```
guiding → [수동 버튼] → countdown(3,2,1) → capturing → analyzing → result
```

#### 개선 플로우
```
cameraSetup (카메라 선택: 전면/후면)
  → preparing (실시간 2D pose 감지 시작)
    → GuidanceChecklist:
      ☐ 전신 보임
      ☐ 거리 적정
      ☐ 자세 안정
      ☐ 조명 충분
    → 모두 ✅ → autoCountdown(3,2,1) 또는 [수동 버튼]
      → capturing (3-frame averaging)
        → analyzing (3D pose)
          → result
```

#### 새 CapturePhase enum
```swift
enum PostureCapturePhase: Sendable, Hashable {
    case idle
    case preparing(GuidanceState)  // 실시간 감지 + 가이드
    case countdown(Int)
    case capturing
    case analyzing
    case result
    case error(String)
}

struct GuidanceState: Sendable, Hashable {
    var isFullBodyVisible: Bool = false
    var distanceStatus: DistanceStatus = .unknown
    var isStable: Bool = false
    var lightingStatus: LightingStatus = .unknown

    var isReady: Bool {
        isFullBodyVisible
        && distanceStatus == .optimal
        && isStable
        && lightingStatus != .tooLow
    }
}
```

## Constraints

### 기술적
- `VNDetectHumanBodyPoseRequest` (2D)는 실시간 가능하나 프레임당 ~10ms (A15+)
- `VNDetectHumanBodyPose3DRequest` (3D)는 ~50-100ms → 프리뷰에 사용 부적합
- 후면 카메라 사용 시 `AVCaptureVideoDataOutput` + `AVCapturePhotoOutput` 동시 설정 필요
- 배터리 소모: 실시간 pose detection은 GPU 사용 → 촬영 중에만 활성화

### 성능 가드레일
- 2D pose detection 프레임 제한: 최대 10fps (매 프레임 불필요)
- 감지 결과 debounce: 500ms 이상 안정 시에만 UI 업데이트
- 카메라 세션 전환 시 기존 세션 완전 정리 후 재설정

### UX
- 가이드가 너무 많으면 오히려 압도감 → 점진적 노출
- 첫 사용 시 온보딩, 이후에는 체크리스트만 표시
- 자동 촬영은 옵션 (기본 ON, 설정에서 OFF 가능)

## Edge Cases

| 케이스 | 대응 |
|--------|------|
| 조명 극도로 부족 | "촬영 불가" 상태 표시 + 촬영 버튼 비활성화 |
| 여러 사람 감지 | 가장 큰(가까운) pose만 사용 + "한 명만 촬영하세요" 안내 |
| 휠체어 사용자 | ankle 미감지 허용 + 상반신 분석 모드 fallback |
| 전면/후면 전환 중 | 세션 완전 정리 → 재설정 (중간 상태 없음) |
| 후면 카메라에서 화면 못 봄 | 음성 + 진동 피드백 필수 |
| 거울 앞 촬영 (반사) | 2개 pose 감지 → "거울 반사가 감지됩니다" 경고 |
| 자동 카운트다운 중 이탈 | pose 유실 시 즉시 카운트다운 취소 + preparing으로 복귀 |

## Scope

### MVP (Must-have)
- [ ] 실시간 2D pose 감지 기반 가이드 피드백 (전신/거리/안정)
- [ ] 존 기반 가이드 오버레이 (점선 실루엣 교체)
- [ ] 상황별 텍스트 힌트
- [ ] 거리 인디케이터
- [ ] 조명 감지 + 경고
- [ ] 자동 카운트다운 (모든 조건 충족 시)
- [ ] 후면 카메라 지원 + 타이머
- [ ] 후면 카메라 음성 카운트다운
- [ ] 카메라 전환 버튼 (전면↔후면)

### Nice-to-have (Future)
- [ ] 첫 사용 온보딩 튜토리얼 (Good/Bad 예시)
- [ ] AR 기반 거리 측정 (LiDAR)
- [ ] 촬영 히스토리에서 "같은 위치에서 촬영" 가이드 (이전 촬영 실루엣 오버레이)
- [ ] 다중 각도 촬영 (정면 + 측면 + 후면)
- [ ] 음성 안내 커스터마이징 (언어, 볼륨)

## Open Questions

1. **자동 촬영 vs 수동 촬영**: 자동을 기본으로 할지, 수동 버튼 클릭을 기본으로 할지?
2. **온보딩 UI**: 별도 온보딩 화면 vs 첫 촬영 시 인라인 가이드?
3. **후면 카메라 음성 피드백**: `AVSpeechSynthesizer` (TTS) vs 미리 녹음된 사운드?
4. **2D pose 프레임레이트**: 5fps vs 10fps — 정확도와 배터리 트레이드오프?
5. **실시간 skeleton 오버레이**: 프리뷰에서 감지된 관절을 실시간으로 보여줄지?

## Technical References

| 파일 | 역할 |
|------|------|
| `DUNE/Data/Services/PostureCaptureService.swift` | 카메라 + pose detection |
| `DUNE/Presentation/Posture/PostureAssessmentViewModel.swift` | 캡처 플로우 상태 관리 |
| `DUNE/Presentation/Posture/PostureCaptureView.swift` | 캡처 UI |
| `DUNE/Presentation/Posture/Components/BodyGuideOverlay.swift` | 현재 가이드 오버레이 |
| `docs/solutions/general/2026-03-15-posture-assessment-vision-3d-pose.md` | Vision API 패턴 |

## Next Steps

- [ ] `/plan posture-capture-guideline-improvement` 으로 구현 계획 생성
