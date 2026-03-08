---
source: brainstorm/vision-pro-production-roadmap
priority: p2
status: ready
created: 2026-03-08
updated: 2026-03-08
---

# Phase 5C: visionOS 고급 기능 (Phase 4 잔여)

## 진행 메모

- Phase 5A 실데이터 연결(`todos/021-done-p1-vision-real-data-pipeline.md`)이 완료됐다.
- Phase 5B UX polish는 `todos/022-in-progress-p2-vision-ux-polish.md`에서 마무리 중이다.
- 따라서 이 TODO는 5B 종료 후 착수하는 다음 phase로 유지한다.

## 목표

SharePlay, Voice Input 등 Phase 4에서 보류된 고급 기능을 구현한다.

## 범위

### 1. G1 SharePlay Shared Workout Space

- Advanced spatial sync scope only
- SharedWorldAnchors로 공유 공간 앵커 정렬
- shareplay board를 RealityKit/volumetric surface에 배치
- 멀티유저 health 비교 및 richer participant placement

### 2. F3 Voice-First Workout Entry

- persistence/audio scope only
- parsed draft → ExerciseRecord save flow 연결
- 음성 피드백 (TTS 또는 spatial audio)
- 한국어/영어/일본어 지원

### 3. Spatial Audio

- 심박수 기반 ambient soundscape
- 호흡 가이드 시 오디오 큐
- Immersive space 모드별 차별화된 사운드

### 4. Hand Tracking 고급

- 호흡 가이드에서 hand tracking으로 호흡 속도 감지
- 근육 모델 직접 회전/조작 (grab gesture)

## 의존성

- Phase 5A (실데이터 연결) 완료 필수
- Phase 5B (UX Polish) 완료 권장
- Apple Vision Pro 실기기 테스트 필수

## 기술 요구사항

- GroupActivities framework
- SFSpeechRecognizer + NLP
- ARKit body tracking
- Spatial audio (RealityKit)
- SharedWorldAnchors API

## 참고

- `docs/brainstorms/2026-03-05-vision-pro-features.md` Categories F, G
- `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` (기존 Phase 4 TODO)
- G1 foundation은 2026-03-08 batch에서 `SharePlay workout board`까지 완료
