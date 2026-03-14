---
tags: [posture, body-assessment, vision-framework, camera, wellness]
date: 2026-03-15
category: brainstorm
status: draft
---

# Brainstorm: 자세 측정 기반 바디 평가 시스템

## Problem Statement

사용자의 자세를 카메라로 측정하여 체형 평가 점수를 제공하고, 주기적 추적을 통해 변화 트렌드를 분석하는 시스템. 전문 트레이너/PT 수준의 분석 품질을 마커 없이 AI만으로 달성하는 것이 핵심 과제.

## Target Users

- **1차**: 전문 트레이너/PT (상세 각도, 비대칭 분석, 클라이언트 리포트)
- **2차**: 체형 관리에 관심 있는 고급 피트니스 사용자
- **사용 시나리오**: 주 1-2회 측정 → 트렌드 확인 → 교정 필요 부위 파악

## Success Criteria

- 마커 없이 Vision 3D Pose로 주요 6개 자세 지표 측정 가능
- 동일 조건 재촬영 시 점수 편차 ±5% 이내 (재현성)
- 기존 WellnessScore + Injury 시스템과 자연스러운 데이터 연계
- 촬영 → 분석 결과까지 10초 이내 (완전 온디바이스)

---

## 경쟁사 분석

### 카테고리별 접근 방식

| 카테고리 | 대표 앱 | 방식 | 정확도 | 비고 |
|---------|---------|------|--------|------|
| 3D 바디 스캔 | ZOZOFIT, Bodygram | 사진 2장 → AI 체형 추정 | 중 | ZOZOFIT: 최근 Posture Mode 추가 (8포인트) |
| 임상 자세 분석 | PostureScreen, APECS | 마커 + 사진 → 각도 측정 | 높음 (ICC 0.90+) | PostureScreen: 월 $49-199, PT/카이로 대상 |
| 실시간 폼 트래킹 | Tempo, Tonal, Asensei | 전용 HW/SDK + 3D 추적 | 높음 | 하드웨어 의존 (Tempo $395+, Tonal $2,995+) |
| 자가 평가 | Pliability, M&M Posture | 가이드 영상 + 설문 | 낮음 | 카메라 측정 없음 |

### 핵심 경쟁사 상세

**ZOZOFIT**
- 사진 기반 3D 체형 스캔 + Posture Mode (8개 포인트)
- 전면/측면 사진 → 정렬 상태 시각화 (초록=정상, 빨강=교정 필요)
- ZOZOSUIT($40) 또는 타이트한 옷 필요
- 12개 신체 치수 + 체지방률 + 3D 모델

**PostureScreen Mobile** (임상 기준선)
- 해부학적 마커 부착 → AI 각도 측정 → PDF 보고서
- 학술 검증: ICC 0.904 (test-retest), 0.889 (inter-rater) — JPTS 2016/2018
- CVA, gaze angle, thoraco-lumbar 각도, 골반 기울기, Q angle 측정
- B2B 모델, 카이로프랙터/PT 대상

**Asensei (APP)ERTURE SDK**
- 단일 카메라 → 골격 길이 추정 기반 3D 모션 캡처
- 픽셀 기반이 아닌 해부학적 골격 데이터 활용
- B2B SDK 라이선싱

### 경쟁 우위 기회

- PostureScreen은 **마커 필수** → 마커 없는 AI 분석으로 접근성 차별화
- ZOZOFIT은 **체형 중심** → 자세 분석은 보조 기능 수준
- Tempo/Tonal은 **하드웨어 종속** → 순수 소프트웨어 솔루션
- 기존 앱들은 **단독 기능** → DUNE은 HRV/수면/운동/부상과 통합 분석 가능

---

## 기술 스택 분석

### Apple Vision Framework (권장)

| 기술 | iOS 지원 | 관절 수 | 카메라 | 특징 |
|------|---------|---------|--------|------|
| Vision 2D Pose | 14+ | 19개 | 전면/후면 | 실시간 30fps+, 가벼움 |
| **Vision 3D Pose** | **17+** | **17개** | **전면/후면** | **미터 단위 3D 좌표, 깊이 추정** |
| ARKit Body | 13+ | ~91개 | 후면만 | AR 오버레이, 월드 앵커링 |
| MediaPipe Pose | cross-platform | 33개 | 전면/후면 | 3rd party, 더 많은 관절 |

**선택: VNDetectHumanBodyPose3DRequest (Vision 3D Pose)**

선택 근거:
- iOS 26 타겟 → iOS 17+ 요구사항 자동 충족
- 전면 카메라 지원 → 셀프 촬영 + 타이머 가능
- 미터 단위 실제 좌표 → 절대 거리/각도 측정
- `centerShoulder`, `spine` 관절 → 흉추 만곡 근사 가능
- `bodyHeight` 제공 → 신체 비율 정규화
- AR 세션 오버헤드 없음
- 완전 온디바이스 → 프라이버시 보장, HIPAA 친화

### 3D Pose 관절 맵 (17 joints)

```
Head:  centerHead, topHead
Torso: centerShoulder, leftShoulder, rightShoulder, spine, root, leftHip, rightHip
Arms:  leftElbow, rightElbow, leftWrist, rightWrist
Legs:  leftKnee, rightKnee, leftAnkle, rightAnkle
```

### 측정 가능한 자세 지표

| 자세 문제 | Vision 3D 관절 | 측정 방법 | 정상 범위 |
|-----------|---------------|----------|----------|
| **거북목** (Forward Head) | centerHead + centerShoulder | 두부 전방 변위 (cm, 3D depth) | <2.5cm 전방 |
| **굽은 어깨** (Rounded Shoulders) | leftShoulder/rightShoulder + spine | 어깨-척추 전방 변위 | <3cm 전방 |
| **흉추 과만곡** (Thoracic Kyphosis) | centerShoulder + spine + root | 3점 각도 | 20-45° |
| **어깨 비대칭** | leftShoulder vs rightShoulder | Y좌표 차이 | <1cm |
| **골반 비대칭** | leftHip vs rightHip | Y좌표 차이 | <1cm |
| **무릎 정렬** (Valgus/Varus) | hip + knee + ankle (각 측) | 전면 Q각 | 12-18° |
| **체간 측방 이동** | centerHead vs root 수직선 | X좌표 편차 | <1cm |
| **체중 분배** | leftAnkle vs rightAnkle | 좌우 위치 비교 | 대칭 |

### 마커 없는 접근의 한계와 대응

| 한계 | 영향 | 대응 |
|------|------|------|
| ASIS/PSIS 미감지 | 골반 전방경사 정밀 측정 불가 | hip + spine + root 3점 프록시 각도 |
| 피부 위 정확한 해부학적 포인트 아님 | ±2-3cm 오차 가능 | 복수 프레임 평균 + 신뢰 구간 표시 |
| 옷에 의한 관절 가림 | confidence 저하 | 타이트한 옷 권장 + 저신뢰 관절 경고 |
| 조명/배경 영향 | 감지 실패 가능 | 촬영 가이드 오버레이 + 품질 검증 단계 |

---

## Proposed Architecture

### 기존 패턴 재활용

| 컴포넌트 | 참고할 기존 패턴 | 위치 |
|---------|----------------|------|
| Data Model | BodyCompositionRecord | Data/Persistence/Models/ |
| ViewModel | BodyCompositionViewModel | Presentation/BodyComposition/ |
| 신체 부위 매핑 | InjuryBodyMapView + BodyPart enum | Presentation/Injury/, Domain/Models/ |
| 트렌드 차트 | TrendChartView | Presentation/Dashboard/Components/ |
| 폼 시트 | BodyCompositionFormSheet | Presentation/BodyComposition/ |
| 점수 카드 | WellnessScore 카드 | Presentation/Wellness/ |

### 신규 컴포넌트

```
DUNE/
├── Domain/Models/
│   ├── PostureAssessment.swift          # 자세 평가 도메인 모델
│   ├── PostureMetric.swift              # 개별 지표 (CVA, 어깨 비대칭 등)
│   └── PostureScore.swift               # 종합 점수 계산 로직
│
├── Domain/Services/
│   └── PostureAnalysisService.swift     # 관절 좌표 → 자세 지표 변환
│
├── Data/Persistence/Models/
│   └── PostureAssessmentRecord.swift    # SwiftData @Model
│
├── Data/Services/
│   ├── PostureCaptureService.swift      # 카메라 + Vision 3D Pose
│   └── PostureQueryService.swift        # 히스토리 조회
│
└── Presentation/Posture/
    ├── PostureCaptureView.swift          # 카메라 UI + 가이드 오버레이
    ├── PostureAnalysisView.swift         # 결과 + 시각화
    ├── PostureHistoryView.swift          # 트렌드 차트
    ├── PostureDetailView.swift           # 개별 지표 상세
    └── PostureAssessmentViewModel.swift  # @Observable
```

### 시스템 연동

```
[Camera Capture] → [Vision 3D Pose] → [PostureAnalysisService]
                                              ↓
                                    [PostureAssessment]
                                      ↓           ↓
                            [WellnessScore]   [InjuryRisk]
                            (Posture Score     (자세 문제 →
                             항목 추가)        부상 위험 연계)
                                      ↓
                            [PostureAssessmentRecord]
                            (SwiftData + CloudKit sync)
```

---

## Phase 분리 (전체 MVP, 단계적 구현)

### Phase 1: 코어 측정 엔진 (Foundation)

**목표**: 카메라 → 관절 감지 → 기본 자세 지표 산출

- [ ] Vision 3D Pose 카메라 캡처 파이프라인
- [ ] 촬영 가이드 오버레이 (전신 프레임, 발 위치 가이드)
- [ ] 전면/측면 2장 촬영 UX (타이머 + 셀프모드)
- [ ] 관절 좌표 → 6개 자세 지표 변환 알고리즘
- [ ] 복수 프레임 평균화 (안정성 향상)
- [ ] 촬영 품질 검증 (전신 감지 여부, confidence 임계값)
- [ ] PostureAssessment 도메인 모델
- [ ] PostureAssessmentRecord (SwiftData)

### Phase 2: 점수화 + 시각화

**목표**: 측정 결과를 이해하기 쉬운 점수와 시각으로 전달

- [ ] 종합 Posture Score (0-100, 가중 복합 점수)
- [ ] 개별 지표별 정상/주의/위험 분류
- [ ] 신체 정렬 오버레이 시각화 (촬영 사진 위 관절/선 표시)
- [ ] Plumb line 분석 시각화 (이상 정렬선 vs 실제)
- [ ] 전면/측면 비교 레이아웃
- [ ] WellnessScore에 Posture Score 통합
- [ ] Wellness 탭 Physical 섹션에 카드 추가

### Phase 3: 히스토리 + 트렌드

**목표**: 시간에 따른 변화 추적, 개선/악화 패턴 분석

- [ ] 주간/월간 트렌드 차트 (기존 TrendChartView 패턴)
- [ ] 이전 측정과 비교 뷰 (Before/After)
- [ ] 지표별 변화율 분석
- [ ] Injury 시스템 연계 (자세 문제 부위 → 부상 위험 알림)
- [ ] 측정 리마인더 (주 1회 권장)
- [ ] CloudKit 동기화 (디바이스 간 히스토리)

### Phase 4: 전문가 기능

**목표**: PT/트레이너가 클라이언트 분석에 활용할 수 있는 수준

- [ ] 상세 각도 수치 표시 (degree 단위)
- [ ] 좌우 비교 상세 분석
- [ ] PDF/이미지 보고서 내보내기
- [ ] 실시간 영상 분석 모드 (움직임 중 자세 평가)
- [ ] 측정 신뢰 구간 표시

---

## Constraints

### 기술적 제약
- **Vision 3D Pose**: iOS 17+ 필수 (앱 타겟 iOS 26이므로 문제 없음)
- **관절 한계**: 17개 관절만 제공 — ASIS/PSIS 직접 감지 불가, 프록시 측정 필요
- **마커 없는 정확도**: PostureScreen (ICC 0.90) 대비 낮을 수 있음 → 재현성 기준으로 보완
- **조명/배경 의존성**: 저조도, 복잡한 배경에서 confidence 저하
- **단일 인물**: Vision 3D는 한 번에 한 명만 분석

### 프라이버시 제약
- 촬영된 사진/영상은 디바이스에서만 처리, 서버 전송 없음
- PostureAssessmentRecord에 원본 이미지 저장 여부 결정 필요
  - 저장 시: Before/After 비교 가능, 저장 용량 증가
  - 미저장 시: 프라이버시 최대, 관절 좌표 + 점수만 보관
- 카메라 권한 (NSCameraUsageDescription) 추가 필요

### 레이어 경계 제약
- Domain은 Vision/AVFoundation import 금지 → PostureAnalysisService는 순수 좌표 입력만 받음
- 카메라/Vision 파이프라인은 Data 레이어에 배치
- ViewModel은 SwiftData import 금지 (기존 규칙)

---

## Edge Cases

| 상황 | 대응 |
|------|------|
| 전신이 프레임에 안 들어옴 | 촬영 가이드 + 실시간 감지 피드백, 재촬영 유도 |
| 관절 confidence가 임계값 미달 | 해당 지표 "측정 불가" 표시, 부분 결과 제공 |
| 옷이 두꺼워 관절 오감지 | 타이트한 옷 권장 안내, confidence 기반 경고 |
| 바닥이 기울어진 곳에서 촬영 | 양 발목 기준선 보정 알고리즘 |
| 같은 자세인데 촬영 각도로 점수 변동 | 카메라 높이/거리 가이드, 복수 프레임 평균 |
| 역대 데이터 없이 첫 측정 | "기준선 측정" 모드, 비교 없이 절대 점수만 표시 |
| 신체 장애/비대칭이 선천적인 경우 | 개인 기준선 설정 기능 (정상 범위 커스터마이징) |

---

## Open Questions

1. **원본 이미지 저장 정책**: 관절 좌표만 저장 vs 촬영 사진 함께 저장? Before/After UX에 큰 영향
2. **Posture Score 가중치**: 어떤 지표를 더 중요하게 반영할지 (거북목 > 골반 비대칭?)
3. **측면 촬영 자동화**: 전면/측면 전환을 사용자 수동으로 할지, 회전 가이드 제공할지
4. **watchOS 연계**: Watch에서 자세 알림/리마인더만 할지, Apple Watch 센서(가속도계) 기반 일상 자세 모니터링까지 확장할지
5. **향후 교정 운동 추천**: Phase 확장 시 기존 Exercise 시스템과 어떻게 연계할지
6. **visionOS 확장**: Vision Pro의 깊이 센서로 더 정밀한 3D 바디 스캔 가능 — 별도 brainstorm 필요?

---

## Next Steps

- [ ] `/plan posture-assessment-phase1` 으로 Phase 1 코어 측정 엔진 구현 계획 생성
- [ ] Vision 3D Pose PoC (Proof of Concept) — 관절 감지 정확도 실측
- [ ] Posture Score 가중치 결정 (의학 문헌 기반)
- [ ] 촬영 UX 프로토타입 (가이드 오버레이 디자인)
