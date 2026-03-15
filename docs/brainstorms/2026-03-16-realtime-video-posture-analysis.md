---
tags: [posture, realtime, vision, camera, exercise-form]
date: 2026-03-16
category: brainstorm
status: draft
---

# Brainstorm: 실시간 영상 자세 분석

## Problem Statement

현재 자세 분석은 **정지 사진 캡처 → 분석** 방식으로, 운동 중 동적 자세 변화를 추적할 수 없다.
실시간 카메라 피드에서 연속적으로 자세를 분석하여 운동 폼 체크와 일상 자세 모니터링을 제공한다.

## Target Users

- **운동 중 폼 체크**: 혼자 운동하면서 스쿼트/데드리프트 자세를 실시간 확인하고 싶은 사용자
- **일상 자세 모니터링**: 서 있거나 앉아 있을 때 자세를 실시간으로 점검하고 싶은 사용자

## Success Criteria

1. 3D 포즈 감지를 실시간 비디오 프레임에서 수행 (목표 15-30fps, 최소 10fps)
2. 운동 폼 판정 정확도: 숙련자 기준 80% 이상 일치
3. 세트 녹화 → 리플레이 시 구간별 점수 제공
4. 음성 코칭이 실제 교정 타이밍에 맞게 전달 (지연 < 500ms)

## Constraints

- **타겟 디바이스**: A17+ (최신 기기만) — Neural Engine 활용 전제
- **카메라 고정**: 초기 MVP는 삼각대 고정 전제 (핸드헬드는 Future)
- **배터리/발열**: 초기엔 시간 제한 없이 구현, 문제 발생 시 대응
- **3D 감지 비용**: `VNDetectHumanBodyPose3DRequest`는 프레임당 ~50-100ms (A17 Pro)
  - 매 프레임 3D 불가 → **2D 연속 + 주기적 3D 샘플링** 전략 필요

## 기존 인프라 활용

### 이미 구축된 것
- `AVCaptureSession` (front/back camera, photo + video output)
- 2D 실시간 감지 10fps (`VNDetectHumanBodyPoseRequest`)
- `BodyGuideOverlay` 스켈레톤 렌더링 (Canvas 기반)
- `PostureAnalysisService` 순수 SIMD 수학 (3D 관절 → 각도/비대칭 계산)
- `PostureGuidanceAnalyzer` (거리, 안정성, 조도 판정)

### 확장/신규 필요
- 3D 감지 비디오 프레임 적용 (현재 사진만)
- 시계열 관절 데이터 버퍼 (궤적 추적)
- 운동별 폼 판정 로직 (Domain)
- 녹화/리플레이 시스템
- 음성 피드백 엔진 (AVSpeechSynthesizer 또는 사전 녹음)

## Technical Approach

### 듀얼 파이프라인 전략

```
Camera Frame (30fps)
    ├─ [매 프레임] 2D Pose Detection → 스켈레톤 오버레이 + 기본 각도
    └─ [매 N프레임] 3D Pose Detection → 정밀 분석 + 점수 업데이트
```

- **2D 연속 스트림**: 관절 위치, 기본 각도(무릎 굴곡, 허리 기울기) 실시간 표시
- **3D 주기적 샘플**: 3-5fps로 3D 감지 → 정밀 metric 업데이트
- 2D↔3D 보간으로 부드러운 UX 유지

### 운동 폼 판정 아키텍처

```
Domain/Models/ExerciseFormRule.swift
  - 운동별 체크포인트 정의 (스쿼트: 깊이, 무릎 방향, 허리 중립 등)

Domain/Services/ExerciseFormAnalyzer.swift
  - 시계열 관절 데이터 → 운동 phase 감지 (하강/최저점/상승)
  - phase별 체크포인트 판정
  - 순수 SIMD, Vision/UI 의존 없음

Data/Services/RealtimePoseTracker.swift
  - 듀얼 파이프라인 관리
  - 관절 시계열 버퍼 (최근 N초)
  - 3D 샘플링 스케줄링
```

### 초기 지원 운동

| 운동 | 주요 체크포인트 | 난이도 |
|------|----------------|--------|
| Squat | 깊이(hip-knee), 무릎 방향(valgus), 허리 중립 | 중 |
| Deadlift | 허리 굴곡, 바벨 경로, hip hinge | 상 |
| Overhead Press | 팔 경로, 허리 과신전, lockout | 중 |

## Edge Cases

- **프레임 드롭**: 3D 감지 지연 시 2D 결과로 graceful degradation
- **사람 감지 실패**: 프레임 중 일시적 미감지 → 마지막 유효 결과 유지 (300ms timeout)
- **다중 인물**: 가장 큰 바운딩박스 1명만 추적
- **역광/저조도**: 기존 `LightingStatus` 재활용 + 경고
- **운동 phase 오판**: 연속 N프레임 일관성 확인 (debounce)

## Scope

### Phase 4A: 실시간 스켈레톤 + 각도 표시 (MVP)
- 2D 연속 + 3D 주기적 듀얼 파이프라인
- 실시간 관절 각도 오버레이 (무릎, 허리, 어깨)
- 일상 자세 실시간 점수 (기존 PostureAnalysisService 재활용)
- 카메라 고정 전제

### Phase 4B: 운동 폼 판정
- 운동 선택 → 폼 체크 모드 진입
- 운동 phase 자동 감지 (하강/최저점/상승)
- 체크포인트별 pass/caution/fail 실시간 표시
- 초기 운동: Squat, Deadlift, Overhead Press

### Phase 4C: 세트 녹화 & 리플레이
- 세트 전체 비디오 + 관절 데이터 동시 녹화
- 리플레이 시 프레임별 스켈레톤/각도 오버레이
- 구간별(렙별) 점수 + 최악 구간 하이라이트
- 세트 간 비교

### Phase 4D: 음성 코칭
- 실시간 음성 피드백 ("무릎을 더 밖으로", "허리 펴세요")
- 교정 타이밍: 문제 감지 후 500ms 이내
- 반복 억제: 같은 교정을 연속 제공하지 않음 (최소 5초 간격)
- AVSpeechSynthesizer (MVP) → 사전 녹음 음성 (Future)

## Open Questions

1. 3D 감지 주기 최적값은? (실측 벤치마크 필요 — A17 Pro에서 3fps vs 5fps)
2. 녹화 데이터 저장 형식? (비디오 + 관절 JSON sidecar vs 커스텀 포맷)
3. 운동 폼 규칙을 사용자가 커스터마이징할 수 있어야 하나? (Future로 보류)
4. 핸드헬드 지원 시 카메라 모션 보정 전략은? (Future)

## Next Steps

- [ ] /plan 으로 Phase 4A 구현 계획 생성
- [ ] A17 Pro에서 3D 감지 프레임 레이트 벤치마크
- [ ] 운동별 폼 체크포인트 상세 스펙 정의
