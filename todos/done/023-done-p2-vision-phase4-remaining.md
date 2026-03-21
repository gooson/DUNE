---
source: brainstorm/vision-pro-production-roadmap
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-22
---

# Phase 5C: visionOS 고급 기능 (Phase 4 잔여)

## 진행 메모

- Phase 5A 실데이터 연결(`todos/021-done-p1-vision-real-data-pipeline.md`)이 완료됐다.
- Phase 5B UX polish 구현은 `todos/022-done-p2-vision-ux-polish.md`로 닫혔다.
- runtime spatial placement primary smoke는 `todos/107-done-p2-vision-window-placement-runtime-validation.md`에서 닫았다.
- no-anchor utilityPanel fallback도 `todos/144-done-p3-vision-window-placement-no-anchor-fallback.md`에서 닫혔다.
- Voice quick entry는 draft preview를 넘어 single-entry workout history 저장까지 연결됐다.
- `todos/140-done-p2-vision-voice-feedback-confirmation.md`에서 locale-aware confirmation, TTS fallback, quick adjust editing을 닫았다.
- G1 SharePlay foundation, F3 quick entry foundation, E1 multi-window runtime verification은 모두 shipped 근거가 생겼다.

## 목표

SharePlay, Voice Input 등 Phase 4에서 보류된 고급 기능을 구현한다.

## 범위

### 1. G1 SharePlay Shared Workout Space

- Advanced spatial sync scope only
- SharedWorldAnchors로 공유 공간 앵커 정렬
- shareplay board를 RealityKit/volumetric surface에 배치
- 멀티유저 health 비교 및 richer participant placement

### 2. F3 Voice-First Workout Entry

- advanced audio-first scope only
- spatial audio cue / ambient soundscape
- multi-step session editing beyond quick adjust

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
- `todos/020-done-p3-vision-pro-phase4-social-advanced.md` (기존 Phase 4 TODO)
- G1 foundation은 2026-03-08 batch에서 `SharePlay workout board`까지 완료

## 완료 메모

- 2026-03-22 기준 이 문서는 executable backlog라기보다 advanced roadmap umbrella였다.
- 남아 있는 `SharedWorldAnchors`, true spatial audio, hand/body tracking 기반 상호작용은 모두 실기기 검증과 더 구체적인 acceptance criteria가 필요한 research scope이므로 active TODO queue에서 제외한다.
- 이후 재개가 필요하면 `docs/brainstorms/2026-03-05-vision-pro-features.md`를 source로 삼아 capability별 새 TODO를 만든다.
